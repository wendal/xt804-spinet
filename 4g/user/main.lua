
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "xt804master"
VERSION = "1.0.1"

--[[
本demo分成主从两部分, 这里是SPI主机, Air780E
]]

sys = require("sys")

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end

sys.taskInit(function()
    sys.wait(500)
    local SPI_ID = 0
    local result = spi.setup(SPI_ID, nil, 0 , 0, 8, 25600 * 1000)
    local PIN_CS = gpio.setup(8, 1, gpio.PULLUP)
    log.info("xcmd", "SPI初始化完成", result)
    xtspi = require "xtspi"
    xtspi.init(SPI_ID, PIN_CS)

    local rxbuff = zbuff.create(1500)
    local txbuff = zbuff.create(1400)

    txbuff:seek(0)
    txbuff:copy(nil, "wlan.init()  return wlan.connect(\"luato1234\", \"12341234\", 1)")
    local len = txbuff:used()
    txbuff:seek(0)
    result = xtspi.write_xcmd(0x40, txbuff, len)
    sys.wait(100)
    
    while true do
        -- 测试一下收发
        -- result = xtspi.write_xcmd(0x01, nil, 0)
        txbuff:seek(0)
        txbuff:copy(nil, "print(" .. tostring(os.time()) .. ")")
        local len = txbuff:used()
        txbuff:seek(0)
        result = xtspi.write_xcmd(0x40, txbuff, len)
        log.info("xcmd", "发送结果", result)
        sys.wait(100)
        rxbuff:seek(0)
        result = xtspi.read_xcmd(0x00, rxbuff)
        if result then
            log.info("xcmd","接收结果", result, rxbuff:query(0, 16):toHex())
            local len = rxbuff[2] + rxbuff[3] * 256 - 8
            if len > 0 then
                log.info("xcmd","返回的数据是", rxbuff:toStr(12, len))
            end
        end
        sys.wait(1000)
    end
end)

-- 结尾总是这一句哦
sys.run()
