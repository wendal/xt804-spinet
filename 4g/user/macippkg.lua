
-- MAC数据分析

local macippkg = {}

function macippkg.decode_mac(buff)
    local pkg = {}
    pkg.dst = buff:read(6)
    pkg.src = buff:read(6)
    _, pkg.type = buff:unpack(">H")

    return pkg
end

function macippkg.decode_ip(buff)
    local tmp = buff:read(1):byte()
    local pkg = {}
    pkg.version = tmp >> 4
    pkg.hlen = tmp & 0x0f
    pkg.type = buff:read(1):byte()
    _, pkg.plen = buff:unpack(">H")
    pkg.token = buff:read(2)
    pkg.flags = buff:read(2)
    _, pkg.ttl, pkg.prot, pkg.crc = buff:unpack(">bbH")
    pkg.src = buff:read(4)
    pkg.dst = buff:read(4)
    -- pkg.offset = buff:used()

    return pkg
end

local function dhcp_buff2ip(buff)
    return string.format("%d.%d.%d.%d", buff:byte(1), buff:byte(2), buff:byte(3), buff:byte(4))
end

local function udp_cheksum(buff)

end

local function tcp_cheksum(buff)

end

local function ip_cheksum(buff)

end

function macippkg.decode(buff, debug)
    local macpkg = macippkg.decode_mac(buff)
    if 0x0800 == macpkg.type then
        macpkg.ippkg  = macippkg.decode_ip(buff)
        if macpkg.ippkg.version == 4 then
            -- 分析一下具体的协议
            if macpkg.ippkg.prot == 1 then
                -- ICMP协议
                macippkg.icmp = {}
            elseif macpkg.ippkg.prot == 0x06 then
                -- TCP协议
                macippkg.tcp = {}
            elseif macpkg.ippkg.prot == 0x11 then
                -- UDP协议
                macippkg.udp = {}
            end
        end
    end

    if debug then
        log.info("MAC数据分析", macpkg.dst:toHex(), macpkg.src:toHex(), macpkg.type)
        if macpkg.ippkg then
            log.info("IP数据包", "版本号", macpkg.ippkg.version, "头部长度", macpkg.ippkg.hlen * 4)
            log.info("IP数据包", "类型", macpkg.ippkg.type, "数据长度", macpkg.ippkg.plen)
            log.info("IP数据包", "TTL", macpkg.ippkg.ttl, "协议", macpkg.ippkg.prot)
            log.info("IP数据包", "源IP", dhcp_buff2ip(macpkg.ippkg.src), "目标IP", dhcp_buff2ip(macpkg.ippkg.dst))
        end
    end
end

return macippkg
