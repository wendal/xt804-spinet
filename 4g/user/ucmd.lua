local ucmd = {}

local resp_map = {}

function ucmd.on_resp(rxbuff, len)
    -- 首先, 解析出里面的cmd和cmdid
    local cmd = rxbuff[4]
    local cmdid = rxbuff[6] + rxbuff[7] * 256
    -- log.info("cmd是", cmd, "cmdid是", cmdid)
    if cmd == 0x81 or cmd == 0x82 then
        cmdid = rxbuff[6 + 4] + rxbuff[7 + 4] * 256
        log.info("回应的cmdid", cmdid)
        -- 这属于命令的返回, 需要看看有没有在等待
        local resp = resp_map[cmdid]
        if resp then
            resp(rxbuff, len)
        else
            sys.publish("UCMD_IN", {cmdid = cmdid, len = len})
        end
    elseif ucmd.user_cb then
        ucmd.user_cb(rxbuff, len)
    end
end

function ucmd.main_task(user_cb)
    ucmd.user_cb = user_cb
    local rxbuff = zbuff.create(1500)
    local result = nil
    while 1 do
        rxbuff:seek(0)
        rxbuff[0] = 0
        result = xtspi.read_xcmd(0x00, rxbuff)
        if result then
            ucmd.on_resp(rxbuff, result)
        end
        sys.waitUntil("UCMD_EVT", 5)
    end
end

function ucmd.ping()
    local result = xtspi.write_xcmd(0x01, nil, 0)
    sys.publish("UCMD_EVT", result)
    -- log.info("等待ping的回应", result)
    if result then
        resp_map[result] = function(rxbuff, len)
            resp_map[result] = nil
            local tmp = rxbuff:toStr(12, len - 8)
            -- log.info("ping的回应", tmp)
            sys.publish("UCMD_PING_RESP", tmp)
        end
        -- log.info("映射ping的响应函数", resp_map[result], "并等待500ms")
        result, data = sys.waitUntil("UCMD_PING_RESP", 500)
        -- log.info("等待结果", result, data)
        if data then
            return data
        end
    end
end

return ucmd
