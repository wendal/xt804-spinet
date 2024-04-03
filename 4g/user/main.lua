
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
    ucmd = require "ucmd"
    xtspi.init(SPI_ID, PIN_CS)

    sys.taskInit(ucmd.main_task)

    ucmd.ping()
    log.info("ucmd", "sta mac地址是", ucmd.call("wlan.getMac"))
    -- ucmd.subscribe("IP_READY")
    -- ucmd.subscribe("IP_LOSE")
    ucmd.subscribe("WLAN_STATUS")
    sys.wait(500)
    ucmd.eval("print(os.time())")
    sys.wait(500)
    ucmd.call("wlan.init", 100)
    sys.wait(500)
    ucmd.call("wlan.connect", 500, "luatos1234", "12341234", 1)
    sys.wait(10000)
    local info = ucmd.call("wlan.getInfo")
    log.info("wlan信息", info and json.encode(info))
end)


-- sys.subscribe("IP_READY",function(id, ip)
--     log.info("ucmd", "IP_READY!!!", id, ip)
-- end)

-- sys.subscribe("IP_LOSE",function(id, ip)
--     log.info("ucmd", "IP_READY!!!", id, ip)
-- end)

sys.subscribe("WLAN_STATUS",function(status)
    log.info("ucmd", "WLAN_STATUS", status)
end)

-- 结尾总是这一句哦
sys.run()
