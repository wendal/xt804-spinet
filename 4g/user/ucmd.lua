local ucmd = {}

function ucmd.on_resp(rxbuff)
    
end

function ucmd.main_task()
    local rxbuff = zbuff.create(1500)
    while 1 do
        rxbuff:seek(0)
        rxbuff[0] = 0
        result = xtspi.read_xcmd(0x00, rxbuff)
        if result then
            sys.publish("UCMD_IN", rxbuff)
        end
        sys.waitUntil("UCMD_EVT", 5)
    end
end

function ucmd.ping()
    local result = xtspi.write_xcmd(0x01, nil, 0)
    if result then
        while 1 do
            sys.waitUntil("UCMD_IN", 5)
        end
    end
end

return ucmd
