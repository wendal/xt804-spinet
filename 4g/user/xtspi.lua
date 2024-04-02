local xtspi = {}

xtspi.tmpbuff = zbuff.create(4)
xtspi.txid = 1

function xtspi.init(id, pin_cs)
    xtspi.id = id
    if type(pin_cs) == "number" then
        xtspi.PIN_CS = gpio.setup(pin_cs, 1, gpio.PULLUP)
    else
        xtspi.PIN_CS = pin_cs
    end
end

function xtspi.wrtie_reg(addr, buff, len)
    -- log.info("xtspi", "写寄存器", string.format("%02X", addr), buff:toStr(buff:used(), 4):toHex())
    xtspi.PIN_CS(0)
    spi.send(xtspi.id, string.char((addr & 0xFF) | 0x80))
    spi.send(xtspi.id, buff, len)
    xtspi.PIN_CS(1)
end

function xtspi.read_reg(addr, buff, len)
    -- log.info("寄存器读取", addr, buff, len)
    -- 尝试读取
    if not len or len < 1 or len > 4 then
        return
    end
    xtspi.PIN_CS(0)
    spi.send(xtspi.id, string.char(addr & 0xFF))
    spi.recv(xtspi.id, len, buff)
    xtspi.PIN_CS(1)
    return true
end

function xtspi.wrtie_data(addr, buff, len)
    if len < 1 then return end
    for i = 0, len - 4, 4 do
        xtspi.wrtie_reg(addr, buff, 4)
        buff:seek(4, zbuff.SEEK_CUR)
    end
    xtspi.wrtie_reg(addr + 0x10, buff, 4)
    buff:seek(4, zbuff.SEEK_CUR)
end

function xtspi.read_data(addr, buff, len)
    -- 尝试读取
    if not len or len < 1 or len > 1500 then
        return
    end
    for i=0,len-4,4 do
        xtspi.read_reg(addr, buff, 4)
    end
    xtspi.read_reg(addr + 0x10, buff, 4)
    return true
end

function xtspi.write_xcmd(cmd, buff, len)
    -- 先读取一下,看从机是否可写
    local tmpbuff = xtspi.tmpbuff
    tmpbuff:seek(0)
    xtspi.read_reg(0x03, tmpbuff, 2)
    if (tmpbuff[0] & 0x01) == 0 then
        log.info("xcmd", "从机无buff可用,需要等待")
        return
    end

    local addr = 0x00

    tmpbuff:seek(0)
    tmpbuff[0] = 0xA5
    tmpbuff[1] = 0 -- 暂时不算checksum
    tmpbuff[2] = (len + 4) & 0xff
    tmpbuff[3] = ((len + 4) >> 8) & 0xff
    local txid = xtspi.txid
    xtspi.wrtie_reg(addr, tmpbuff, 4)

    tmpbuff:seek(0)
    tmpbuff[0] = cmd & 0xff
    tmpbuff[1] = (cmd >> 8) & 0xff
    tmpbuff[2] = txid & 0xff
    tmpbuff[3] = (txid >> 8) & 0xff
    if len > 0 then
        -- log.info("xcmd", "分段发送", len)
        xtspi.wrtie_reg(addr, tmpbuff, 4)
        xtspi.wrtie_data(addr, buff, len)
    else
        -- log.info("xcmd", "没有附加数据,直接发送结尾")
        xtspi.wrtie_reg(addr + 0x10, tmpbuff, 4)
    end
    xtspi.txid = xtspi.txid + 1
    return txid
end

function xtspi.read_xcmd(addr, buff)
    -- 首先, 读取一下是否真有的数据
    local tmpbuff = xtspi.tmpbuff
    tmpbuff:seek(0)
    tmpbuff[0] = 0
    tmpbuff[1] = 0
    xtspi.read_reg(0x02, tmpbuff, 2)
    local rlen = tmpbuff[0] | tmpbuff[1] << 8
    -- log.info("xcmd", "可读取长度是", rlen)
    if rlen < 4 then
        log.info("xcmd", "待读取数据不够")
        return
    end

    -- 尝试读取
    tmpbuff:seek(0)
    xtspi.read_reg(addr, buff, 4)
    if buff[0] ~= 0xA5 then
        xtspi.read_reg(addr + 0x10, buff, 4) -- 将数据清空
        -- log.info("xtspi", "read_xcmd: invalid header")
        return
    end
    local len = (buff[2] | buff[3] << 8)
    if len > 1500 - 4 then
        xtspi.read_reg(addr + 0x10, buff, 4) -- 将数据清空
        log.info("xtspi", "read_xcmd: invalid len")
        return
    end
    xtspi.read_data(addr, buff, len)
    return len
end

return xtspi
