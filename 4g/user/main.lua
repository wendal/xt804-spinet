
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "xt804master"
VERSION = "1.0.1"

--[[
本demo分成主从两部分, 这里是SPI主机, Air780E
]]

sys = require("sys")
require("sysplus")
udpsrv = require("udpsrv")

local ulwip_aindex = socket.LWIP_STA
local apindex = socket.LWIP_AP

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end

local SPI_ID = 0
local result = spi.setup(SPI_ID, nil, 0 , 0, 8, 25600 * 1000)
local PIN_CS = gpio.setup(8, 1, gpio.PULLUP)
log.info("xcmd", "SPI初始化完成", result)
xtspi = require "xtspi"
ucmd = require "ucmd"

function ucmd_user_cb(cmd, rxbuff, len)
    if cmd == 0x10 then
        local id = rxbuff[8] + rxbuff[9] * 256
        local dlen = rxbuff[10] + rxbuff[11] * 256
        log.info("ucmd", "收到mac包", dlen)
        ulwip.input(id == 0 and ulwip_aindex or apindex, rxbuff, dlen, 12)
    end
end

function netif_write_out(id, data)
    ucmd.macpkg(id == 0 and ulwip_aindex or apindex, data)
end

function ulwip_sta(sta_mac)
    ucmd.call("wlan.connect", 500, "luatos1234", "12341234", 1)
    sys.waitUntil("WLAN_STATUS", 10000)
    local info = ucmd.call("wlan.getInfo")
    log.info("wlan信息", info and json.encode(info))

    -- 然后初始化ulwip
    ulwip.setup(ulwip_aindex, (sta_mac:fromHex()), netif_write_out, {zbuff_out=true})
    ulwip.reg(ulwip_aindex)
    ulwip.updown(ulwip_aindex, true)
    ulwip.link(ulwip_aindex, true)
    -- ulwip.ip(ulwip_aindex, "192.168.1.129", "255.255.255.0", "192.168.1.1")
    ulwip.dhcp(ulwip_aindex, true)
    -- socket.setDNS(ulwip_aindex, 1, "192.168.1.1")
    sys.waitUntil("IP_READY", 2500)
    log.info("socket", "sta", socket.localIP(ulwip_aindex))
    -- ulwip.dhcp(ulwip_aindex, true)
    sys.wait(100)
    while 1 do
        -- local code, headers = http.request("GET", "http://192.168.1.5:8000/index.html", nil, nil, {adapter=ulwip_aindex,timeout=5000}).wait()
        -- log.info("http", code, json.encode(headers))
        -- sys.wait(1000)
        -- local code, headers = http.request("GET", "http://8.217.189.231/", nil, nil, {adapter=ulwip_aindex,timeout=5000}).wait()
        -- log.info("http", code, json.encode(headers))
        -- sys.wait(1000)
        local code, headers, body = http.request("GET", "http://httpbin.air32.cn/get", nil, nil, {adapter=ulwip_aindex,timeout=5000}).wait()
        log.info("http", code, json.encode(headers), body)
        sys.wait(1000)
    end
end

function ulwip_ap(ap_mac)
    ucmd.call("wlan.createAP", 500, "luatos-ap", "12341234")

    -- 然后初始化ulwip
    ulwip.setup(apindex, (ap_mac:fromHex()), netif_write_out, {zbuff_out=true})
    ulwip.reg(apindex)
    ulwip.updown(apindex, true)
    ulwip.link(apindex, true)
    ulwip.ip(apindex, "192.168.4.1", "255.255.255.0", "192.168.4.1")

    sys.wait(100)
    dhcpd = udpsrv.create(67, "dhcpd_inc", apindex)
    while 1 do
        log.info("ulwip", "等待DHCP数据")
        local result, data = sys.waitUntil("dhcpd_inc", 1000)
        if result then
            log.info("ulwip", "收到dhcp数据包", data:toHex())
        end
    end
end

sys.taskInit(function()
    sys.wait(500)
    xtspi.init(SPI_ID, PIN_CS)

    sys.taskInit(ucmd.main_task, ucmd_user_cb)

    ucmd.ping()
    local sta_mac = ucmd.call("wlan.getMac") or "C81234567890"
    log.info("ucmd", "sta mac地址是", sta_mac)
    local ap_mac = ucmd.call("wlan.getMac", 100, 1) or "C81234567830"
    log.info("ucmd", "ap mac地址是", ap_mac)

    ucmd.subscribe("WLAN_STATUS")
    sys.wait(100)

    ucmd.call("wlan.init", 100)
    sys.wait(500)

    -- STA测试
    -- sys.taskInit(ulwip_sta, sta_mac)

    -- AP测试
    sys.taskInit(ulwip_ap, ap_mac)
end)

sys.subscribe("WLAN_STATUS",function(status)
    log.info("ucmd", "WLAN_STATUS", status)
end)

-- 结尾总是这一句哦
sys.run()
