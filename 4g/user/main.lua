
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "xt804master"
VERSION = "1.0.1"

--[[
本demo分成主从两部分, 这里是SPI主机, Air780E
]]

mobile.ipv6(false)

sys = require("sys")
require("sysplus")
dnsproxy = require("dnsproxy")
udpsrv = require("udpsrv")
macippkg = require("macippkg")

local ulwip_aindex = socket.LWIP_STA
local apindex = socket.LWIP_AP

napt2 = require("napt2")
napt2.setup(socket.LWIP_GP, apindex)

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end

local SPI_ID = 0
local result = spi.setup(SPI_ID, nil, 0 , 0, 8, 25600000)
local PIN_CS = 8
gpio.setup(8, 1, gpio.PULLUP)
log.info("xcmd", "SPI初始化完成", result)
xtspi = require("xtspi")
ucmd = require("ucmd")


function ucmd_user_cb(cmd, rxbuff, len)
    if cmd == 0x10 then
        local id = rxbuff[8] + rxbuff[9] * 256
        local dlen = rxbuff[10] + rxbuff[11] * 256
        -- log.info("ucmd", "收到mac包", dlen, rxbuff:toStr(0, 32):toHex())
        -- ulwip.input(apindex, rxbuff, dlen, 12)
        ulwip.input(id == 0 and ulwip_aindex or apindex, rxbuff, dlen, 12)
        
        if id == 1 then
            -- 调试用, 打印mac包
            -- rxbuff:seek(12)
            -- macippkg.decode(rxbuff, true)
            napt2.inet_input(rxbuff, 12)
        end
    end
end

function netif_write_out(id, data)
    if id == ulwip_aindex then
        ucmd.macpkg(0, data)
    elseif id == apindex then
        -- 分析下行数据
        data:seek(0)
        -- macippkg.decode(data, true)
        data:seek(#data)
        ucmd.macpkg(1, data)
    elseif id == socket.LWIP_GP then
        -- 4G数据
        -- log.info("ulwip", "收到4G数据")

        -- local tmpbuff = zbuff.create(#data + 14) -- 添加MAC包头的14字节
        -- tmpbuff:seek(14)
        -- tmpbuff:copy(nil, data)
        -- tmpbuff:seek(0)
        -- tmpbuff[12] = 0x08
        -- tmpbuff[13] = 0x00
        -- napt2.iter_input(tmpbuff, 0)
    end
    
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
    
    -- 这里等待4G就绪, 然后再创建AP
    log.info("ulwip", "等待4G联网")
    sys.waitUntil("IP_READY")

    -- 初始化ulwip的GPRS部分
    ulwip.setup(socket.LWIP_GP, "\0\0\0\0\0\0", netif_write_out, {zbuff_out=true, reverse=true})

    log.info("ulwip", "创建AP")
    ucmd.call("wlan.createAP", 500, "luatos-ap", "12341234")

    -- 然后初始化ulwip
    ulwip.setup(apindex, (ap_mac:fromHex()), netif_write_out, {zbuff_out=true})
    ulwip.reg(apindex)
    ulwip.updown(apindex, true)
    ulwip.link(apindex, true)
    ulwip.ip(apindex, "192.168.4.1", "255.255.255.0", "192.168.4.1")

    sys.wait(100)
    dhcpsrv = require("dhcpsrv")
    local opts = {
        adapter = apindex,
        gw = {192, 168, 4, 1},
        mask = {255, 255, 255, 0},
        dns = {192, 168, 4, 1},
        ip_start = 100,
        ip_end = 200
    }
    local dhcpd = dhcpsrv.create(opts)
    dnsproxy.setup(apindex, nil)
    while true do
        sys.wait(1000)
    end
end

sys.taskInit(function()
    -- sys.wait(500)
    -- sys.waitUntil("IP_READY")

    xtspi.init(SPI_ID, PIN_CS)

    sys.taskInit(ucmd.main_task, ucmd_user_cb)

    ucmd.ping()
    sys.wait(100)
    ucmd.call("wlan.init", 100)
    sys.wait(100)

    local sta_mac = ucmd.call("wlan.getMac") or "C81234567890"
    log.info("ucmd", "sta mac地址是", sta_mac)
    local ap_mac = ucmd.call("wlan.getMac", 100, 1) or "C81234567830"
    log.info("ucmd", "ap mac地址是", ap_mac)

    ucmd.subscribe("WLAN_STATUS")
    sys.wait(100)

    -- STA测试
    -- sys.taskInit(ulwip_sta, sta_mac)

    -- AP测试
    sys.taskInit(ulwip_ap, ap_mac)
end)

sys.subscribe("WLAN_STATUS",function(status)
    log.info("ucmd", "WLAN_STATUS", status)
end)

-- 打印一下内存状态
sys.timerLoopStart(function()
    collectgarbage("collect")
    collectgarbage("collect")
    log.info("lua", rtos.meminfo())
    log.info("sys", rtos.meminfo("sys"))
    -- log.info("psram", rtos.meminfo("psram"))
    -- collectgarbage("collect")
end, 2000)

-- 结尾总是这一句哦
sys.run()
