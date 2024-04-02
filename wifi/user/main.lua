
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "spislave"
VERSION = "1.0.1"

--[[
本demo分成主从两部分, 这里是SPI从机, Air601的
]]

sys = require("sys")

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end

sys.taskInit(function()
    sys.wait(500)
    spi804 = require "spi804"
    require "basecmds"
    spi804.init(2)
    sys.taskInit(spi804.main_task)
end)

-- 结尾总是这一句哦
sys.run()
