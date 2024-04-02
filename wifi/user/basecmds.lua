


local spi804 = require("spi804")

--------------------------------------------------
-------------- 基础命令
--------------------------------------------------

-- ping命令
spi804.cmds[0x01] = function(rxbuff, len)
    log.info("cmds", "收到ping命令")
    local tmp = {}
    if _G.VERSION then
        tmp.version = _G.VERSION
    end
    if _G.PROJECT then
        tmp.project = _G.PROJECT
    end
    if mcu then
        tmp.unique_id = mcu.unique_id():toHex()
        tmp.ticks = mcu.ticks()
    end
    if wlan then
        tmp.stamac = wlan.getMac()
        tmp.apmac = wlan.getMac(1)
    end
    spi804.send_resp(rxbuff, true, (json.encode(tmp)))
end

-- 重启命令
spi804.cmds[0x02] = function(rxbuff, len)
    spi804.send_resp(rxbuff, true, _G.VERSION)
    sys.timerStart(rtos.reboot, 1000)
end
-- 获取内存信息
spi804.cmds[0x02] = function(rxbuff, len)
    local meminfo = json.encode({
        lua={rtos.meminfo()},
        sys={rtos.meminfo()}
    })
    spi804.send_resp(rxbuff, true, meminfo)
end

--------------------------------------------------
-------------- FOTA命令
--------------------------------------------------

if fota then
    -- fota初始化
    spi804.cmds[0x20] = function(rxbuff, len)
        local ret = fota.init()
        if ret then
            spi804.send_resp(rxbuff, true)
        else
            spi804.send_resp(rxbuff, false, tostring(ret))
        end
    end
    spi804.cmds[0x21] = function(rxbuff, len)
        local ret = fota.run(rxbuff)
        if ret then
            spi804.send_resp(rxbuff, true)
        else
            spi804.send_resp(rxbuff, false, tostring(ret))
        end
    end
    spi804.cmds[0x22] = function(rxbuff, len)
        local succ, fotaDone = fota.isDone()
        if succ then
            spi804.send_resp(rxbuff, true)
        else
            spi804.send_resp(rxbuff, false)
        end
    end
end

-- 接下来是几条luatos指令

-- 执行lua代码(字符串形式)
spi804.cmds[0x40] = function(rxbuff, len)
    local str = rxbuff:toStr(8, len - 4)
    -- log.info("cmds", "lua字符串??", rxbuff:toStr(0, len + 4):toHex(), rxbuff:used())
    -- log.info("cmds", "lua字符串??", str)
    local ret, result = pcall(function()
        return load(str)()
    end)
    spi804.send_resp(rxbuff, ret, tostring(result))
end

-- 执行函数调用
spi804.cmds[0x41] = function(rxbuff, len)
    local str = rxbuff:toStr(8, len - 4)
    local ret, result = pcall(function()
        local jdata = json.decode(str)
        if jdata then
            local func_name = jdata.func
            local args = jdata.args or {}
            local tmp = func_name:split(".")
            local func = nil
            if #tmp > 1 then
                local m = _G[tmp[1]]
                if m then
                    func = m[tmp[2]]
                end
            else
                func = _G[tmp[1]]
            end
            if func and type(func) == "function" then
                return func(table.unpack(args))
            end
        end
    end)
    spi804.send_resp(rxbuff, ret, result and tostring(result) or "")
end

local function spinet_subscribe(topic, args)
    local jdata = json.encode({topic, args})
    spi804.send_cmd(0x43, jdata)
end

-- 订阅事件
spi804.cmds[0x42] = function(rxbuff, len)
    local topic = rxbuff:toStr(8, len - 4)
    sys.subscribe(topic, function(...)
        spinet_subscribe(topic, {...})
    end)
    spi804.send_resp(rxbuff, true)
end

-- 接收事件, 一般不会用到
spi804.cmds[0x42] = function(rxbuff, len)
    local jdata = json.decode(rxbuff:toStr(8, len - 4))
    sys.publish(jdata[1], table.unpack(jdata[2] or {}))
    spi804.send_resp(rxbuff, true)
end