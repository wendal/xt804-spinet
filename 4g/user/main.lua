
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "xt804master"
VERSION = "1.0.1"

--[[
本demo分成主从两部分, 这里是SPI主机, Air780E
]]

sys = require("sys")
require("sysplus")


local ulwip_aindex = socket.LWIP_STA

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end

function ucmd_user_cb(cmd, rxbuff, len)
    if cmd == 0x10 then
        local id = rxbuff[8] + rxbuff[9] * 256
        local dlen = rxbuff[10] + rxbuff[11] * 256
        log.info("ucmd", "收到mac包", dlen)
        ulwip.input(ulwip_aindex, rxbuff, dlen, 12)
    end
end

function netif_write_out(id, data)
    ucmd.macpkg(id, data)
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

    sys.taskInit(ucmd.main_task, ucmd_user_cb)

    ucmd.ping()
    local mac = ucmd.call("wlan.getMac") or "C81234567890"
    log.info("ucmd", "sta mac地址是", mac)
    -- ucmd.subscribe("IP_READY")
    -- ucmd.subscribe("IP_LOSE")
    ucmd.subscribe("WLAN_STATUS")
    sys.wait(500)
    -- ucmd.eval("print(os.time())")
    -- sys.wait(500)
    ucmd.call("wlan.init", 100)
    sys.wait(500)
    ucmd.call("wlan.connect", 500, "uiot", "12345678", 1)
    sys.waitUntil("WLAN_STATUS", 10000)
    local info = ucmd.call("wlan.getInfo")
    log.info("wlan信息", info and json.encode(info))

    -- 然后初始化ulwip
    ulwip.setup(ulwip_aindex, (mac:fromHex()), netif_write_out)
    ulwip.reg(ulwip_aindex)
    ulwip.updown(ulwip_aindex, true)
    ulwip.dft(ulwip_aindex)
    ulwip.ip(ulwip_aindex, "192.168.1.129", "255.255.255.0", "192.168.1.1")

    log.info("socket", "sta", socket.localIP(ulwip_aindex))
    -- ulwip.dhcp(ulwip_aindex, true)
    sys.wait(100)
    local code = http.request("GET", "http://192.168.1.15:8000/index.html", nil, nil, {adapter=ulwip_aindex,debug=true,timeout=5000}).wait()
    log.info(code)
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
