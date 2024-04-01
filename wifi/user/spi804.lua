local spi804 = {}

spi804.rxbuff = zbuff.create(1500)
spi804.txbuff = zbuff.create(1500)
spi804.txqueue = {}
spi804.txid = 1
spi804.cmds = {}
local TAG = "spi804"

spi804.cmds[0xff] = function(rxbuff, cmdid, len)
    spi804.send_resp(cmdid)
end

function spi804.dft_on_data(rxbuff, len)
    -- 开始进行命令判断
    local cmd, cmdid = rxbuff:unpack("<HH")
    if spi804.cmds[cmd] then
        sys.taskInit(spi804.cmds[cmd], rxbuff, cmdid, len)
    else
        log.info(TAG, "没有找到对应的命令", cmd)
        sys.taskInit(spi804.cmds[0xff], rxbuff, cmdid, len)
    end
end

function spi804.send_resp(cmdid, ack, data)
    local cmd = ack and 0x81 or 0x82
    if not ack then
        data = pack.pack("<H", cmdid)
    end
    table.insert(spi804.txqueue, {ack and 0x81 or 0x82, data})
    sys.publish("SPI804")
end

function spi804.ent(event, ptr, tlen)
    log.info(TAG, event, ptr, tlen)
    if event == 0 then
        log.info(TAG, "cmd数据", ptr, tlen)
    end
    if event == 1 then
        log.info(TAG, "data数据", ptr, tlen)
    end
    if tlen and tlen > 4 then
        local rxbuff = spi804.rxbuff
        spislave.read(spi804.id, ptr, rbuff, tlen)
        log.info(TAG, "数据读取完成,前4个字节分别是", rbuff[0], rbuff[1], rbuff[2], rbuff[3])
        local _, magic, checksum, len = rbuff:unpack("<BBH")
        if not magic or magic ~= 0xA5 then
            log.info(TAG, "数据格式错误, magic对不上")
            return
        end
        if len > 1496 then
            log.info(TAG, "数据长度有问题, 超过限制", len)
        end
        -- TODO 计算校验和
        rxbuff:del(1,4)
        -- 传递给上层
        if spi804.on_data then
            spi804.on_data(rxbuff, len)
        end
    end
end

function spi804.init(mode, on_data)
    spi804.id = mode or 2
    spi804.on_data = on_data or spi804.dft_on_data
    spislave.setup(spi804.id)
    spislave.on(spi804.id, spi804.ent)
    sys.taskInit(spi804.main_task)
end

function spi804.main_task()
    while 1 do
        if #spi804.txqueue > 0 then
            -- 首先, 看看能不能写
            if spislave.ready(spi804.id) then
                local txbuff = spi804.txbuff
                local item = table.remove(spi804.txqueue, 1)
                local cmd, data = table.unpack(item)
                -- 写入CMD ID, 这个是本地的id, 不是远程的id
                txbuff:seek(0)
                txbuff:pack("<BBH", 0xA5, 0, #data + 4) -- TODO 计算checksum
                txbuff.pack("<HH", cmd, spi804.txid)
                txbuff:copy(data)
                spislave.write(spi804.id, txbuff, txbuff:used())
                spi804.txid = spi804.txid + 1
            else
                sys.wait(3) -- 还不空闲, 先等一会
            end
        end
        if #spi804.txqueue == 0 then
            sys.waitUntil("SPI804", 50)
        end
    end
end

return spi804
