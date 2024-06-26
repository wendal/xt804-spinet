
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

function macpkg_up(tp, buff)
    -- log.info("wlan", "MAC包-->上位机", tp, buff:used())
    local len = (buff:used() + 3 + 4) & 0xfffc
    local tmp = zbuff.create(len // 1)
    if tmp == nil then
        buff:seek(0)
        log.error("main", "内存炸了, 无法分配zbuff了")
        collectgarbage("collect")
        collectgarbage("collect")
        return
    end
    tmp:seek(0)
    tmp:pack("<HH", tp, buff:used())
    tmp:copy(nil, buff)
    buff:seek(0) -- 马上释放
    -- log.info("上行MAC封包", tmp:query():toHex())
    spi804.send_cmd(0x10, tmp)
end

sys.taskInit(function()
    sys.wait(500)
    spi804 = require "spi804"
    require "basecmds"
    spi804.init(2)
    wlanraw.setup(0, macpkg_up)
    sys.taskInit(spi804.main_task)
end)

-- 结尾总是这一句哦
sys.run()
