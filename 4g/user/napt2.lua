
local napt2 = {}

napt.init()

-- 定时清理NAPT表
-- sys.timerLoopStart(napt.check, 30000)

local macippkg = require("macippkg")

local function buff2ip(buff)
    return string.format("%d.%d.%d.%d", buff:byte(1), buff:byte(2), buff:byte(3), buff:byte(4))
end

--[[
初始化napt2
@api napt2.setup(out_adapter, in_adapter)
@int 外网端的适配器id
@int 内网端的适配器id
@return bool 初始化成功与否
]]
function napt2.setup(out_adapter, in_adapter)
    napt2.out_adapter = out_adapter
    napt2.in_adapter = in_adapter
    return true
end

--[[
内网段数据包输入
@api napt2.inet_input(buff)
@buff 数据包
]]
function napt2.inet_input(buff, offset)
    if napt2.out_adapter == nil then
        return
    end
    -- 内网数据包
    buff:seek(offset)
    if true then
        -- 是MAC包, 先判断一下是不是广播包,是的话就直接忽略
        if "\xFF\xFF\xFF\xFF\xFF\xFF" == buff:read(6) then
            -- log.info("napt2.inet", "是广播包, 忽略napt2分析", buff:toStr(offset, 12):toHex())
            return
        end
        -- 跳过目标MAC地址
        buff:seek(6, zbuff.SEEK_CUR)
        -- 读取包协议
        local _, proto = buff:unpack(">H")
        if 0x0800 ~= proto then
            -- log.info("napt2.内网出", "不是IP包, 忽略napt2转发", buff:toStr(offset, 12):toHex())
            return
        end
    end
    -- 继续进行IP包分析
    -- local ippkg_offset = buff:used()
    local ippkg = macippkg.decode_ip(buff)
    if ippkg.version ~= 4 then
        -- log.info("napt2.内网出", "不是IPv4的包, 忽略", ippkg.version)
        return
    end
    -- 判断一下目标地址
    local dst1 = ippkg.dst:byte()
    local dst_ip = buff2ip(ippkg.dst)
    if dst1 == 192 or dst1 == 0xFF or dst1 == 172 or dst1 == 127 or dst1 == 0 then
        -- TODO 更准确的内网ip判断
        -- log.info("napt2.内网出", "目标地址是内网, 忽略", dst_ip)
        return
    end
    if ippkg.prot == 1 then
        -- ICMP协议
        -- log.info("napt2.内网出", "ICMP协议,目标地址", dst_ip)
    elseif ippkg.prot == 0x06 then
        -- TCP协议
        -- log.info("napt2.内网出", "TCP协议,目标地址", dst_ip)
    elseif ippkg.prot == 0x11 then
        -- UDP协议
        -- log.info("napt2.内网出", "UDP协议,目标地址", dst_ip)
    else
        log.info("napt2.内网出", "不支持的IP协议, 忽略", ippkg.prot, dst_ip)
        return
    end

    buff:seek(offset)
    if napt.rebuild(buff, true, napt2.out_adapter) then
        -- log.info("napt", "IP包改造完成, 内网->外网")
        -- TODO 发送到外网
    else
        log.info("napt", "IP包改造失败, 内网->外网")
    end
end

--[[
外网段数据包输入
@api napt2.iter_input(buff)
@buff 数据包
]]
function napt2.iter_input(buff, offset)
    if napt2.in_adapter == nil then
        log.info("napt2", "未初始化")
        return
    end
    buff:seek(14, zbuff.SEEK_CUR)
    local ippkg = macippkg.decode_ip(buff)
    if ippkg.version ~= 4 then
        -- log.info("napt2.外网入", "不是IPv4的包, 忽略", ippkg.version)
        return
    end
    -- 判断一下目标地址
    -- local dst1 = ippkg.dst:byte()
    local dst_ip = buff2ip(ippkg.dst)
    -- log.info("napt2.外网入", "目标地址", dst_ip)
    -- if dst1 == 192 or dst1 == 0xFF or dst1 == 172 or dst1 == 127 or dst1 == 0 then
    --     -- TODO 更准确的内网ip判断
    --     log.info("napt2.外网入", "目标地址是内网, 忽略", dst_ip)
    --     return
    -- end
    if ippkg.prot == 1 then
        -- ICMP协议
        -- log.info("napt2.外网入", "ICMP协议,目标地址", dst_ip)
    elseif ippkg.prot == 0x06 then
        -- TCP协议
        -- log.info("napt2.外网入", "TCP协议,目标地址", dst_ip)
    elseif ippkg.prot == 0x11 then
        -- UDP协议
        -- log.info("napt2.外网入", "UDP协议,目标地址", dst_ip)
    else
        -- log.info("napt2.外网入", "不支持的IP协议, 忽略", ippkg.prot, dst_ip)
        return
    end
    buff:seek(offset)
    -- log.info("待转换的数据", buff:toStr(0, #buff):toHex())
    if napt.rebuild(buff, false, napt2.in_adapter) then
        -- log.info("napt", "IP包改造完成, 外网-->内网")
        -- 发送到内网
        -- log.info("转换后的数据", buff:toStr(0, #buff):toHex())
        buff:seek(#buff)
        ucmd.macpkg(1, buff)
    else
        log.info("napt", "IP包改造失败, 外网-->内网")
    end
end

return napt2