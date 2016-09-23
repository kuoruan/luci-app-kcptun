-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"

local m, s, o
local kcptun = "kcptun"
local sid = arg[1]

local encrypt_methods = {
    "aes",
    "aes-128",
    "aes-192",
    "salsa20",
    "blowfish",
    "twofish",
    "cast5",
    "3des",
    "tea",
    "xtea",
    "xor",
    "none",
}
local modes = {
    "normal",
    "fast",
    "fast2",
    "fast3",
    "manual",
}

m = Map(kcptun, translate("Kcptun"))
m.redirect = dsp.build_url("admin/services/kcptun/list")

if m.uci:get(kcptun, sid) ~= "client" then
    luci.http.redirect(m.redirect)
    return
end

s = m:section(NamedSection, sid, "client", translate("Client Manage"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "alias", translate("Alias(optional)"))
o.rmempty = true

o = s:option(Value, "server_ip", translate("Server IP"))
o.datatype = "ipaddr"
o.placeholder = "0.0.0.0"
o.default = "0.0.0.0"
o.rmempty = false

o = s:option(Value, "server_port", translate("Server Port"))
o.datatype = "port"
o.placeholder = "29900"
o.default = "29900"
o.rmempty = false

o = s:option(Value, "local_port", translate("Local Port"), translate("Local listen port."))
o.datatype = "port"
o.placeholder = "12948"
o.default = "12948"
o.rmempty = false

o = s:option(Value, "key", translate("Key"), translate("Pre-shared secret for client and server."))
o.password = true
o.placeholder = "it's a secret"
o.rmempty = true

o = s:option(ListValue, "crypt", translate("crypt"), translate("Encrypt Method"))
for _, v in ipairs(encrypt_methods) do
    o:value(v, v:upper())
end
o.default = "ase"
o.rmempty = false

o = s:option(ListValue, "mode", translate("mode"), translate("Embedded Mode"))
for _, v in ipairs(modes) do
    o:value(v, v:upper())
end
o.default = "fast"
o.rmempty = false

o = s:option(Value, "conn", translate("conn"), translate("Number of UDP connections to server."))
o.datatype = "uinteger"
o.placeholder = "1"
o.rmempty = true

o = s:option(Value, "autoexpire", translate("autoexpire"), translate("Autoexpire, Default unit is seconds"))
o.datatype = "uinteger"
o.placeholder = "60"
o.rmempty = true

o = s:option(Value, "mtu", translate("mtu"), translate("Maximum transmission unit of UDP packets."))
o.datatype = "and('uinteger', max(1500))"
o.placeholder = "1350"
o.rmempty = true

o = s:option(Value, "sndwnd", translate("sndwnd"), translate("Send Window Size(num of packets)."))
o.datatype = "uinteger"
o.placeholder = "128"
o.rmempty = true

o = s:option(Value, "rcvwnd", translate("rcvwnd"), translate("Receive Window Size(num of packets)."))
o.datatype = "uinteger"
o.placeholder = "1024"
o.rmempty = true

o = s:option(Value, "datashard", translate("datashard"), translate("Reed-solomon Erasure Coding - datashard."))
o.datatype = "uinteger"
o.placeholder = "10"
o.rmempty = true

o = s:option(Value, "parityshard", translate("parityshard"), translate("Reed-solomon Erasure Coding - parityshard."))
o.datatype = "uinteger"
o.placeholder = "3"
o.rmempty = true

o = s:option(Value, "dscp", translate("dscp"), translate("DSCP(6bit)"))
o.datatype = "uinteger"
o.placeholder = "0"
o.rmempty = true

o = s:option(Flag, "nocomp", translate("nocomp"), translate("Disable Compression."))
o.enabled = "true"
o.disabled = "false"
o.default = o.disabled
o.rmempty = false

o = s:option(Flag, "nodelay", translate("nodelay"), translate("Enable nodelay Mode."))
o.enabled = "1"
o.disabled = "0"
o.default = o.enabled
o.rmempty = true
o:depends("mode", "manual")

o = s:option(Value, "interval", translate("interval"))
o.datatype = "uinteger"
o.placeholder = "20"
o.rmempty = true
o:depends("mode", "manual")

o = s:option(ListValue, "resend", translate("resend"))
o:value("0", translate("Off"))
o:value("1", translate("On"))
o:value("2", translate("2ed"))
o.default = "2"
o.rmempty = false
o:depends("mode", "manual")

o = s:option(Flag, "nc", translate("nc"))
o.enabled = "1"
o.disabled = "0"
o.default = o.enabled
o.rmempty = true
o:depends("mode", "manual")

o = s:option(Flag, "acknodelay", translate("acknodelay"))
o.enabled = "true"
o.disabled = "false"
o.default = o.disabled
o.rmempty = true
o:depends("mode", "manual")

o = s:option(Value, "sockbuf", translate("sockbuf"), translate("Send/secv buffer size of udp sockets, default unit is MB"))
o.datatype = "uinteger"
o.placeholder = "4"
o.rmempty = true
function o.cfgvalue(self, section)
    local value = Value.cfgvalue(self, section)

    if value then
        return tonumber(value) / 1024 /1024
    end
end
function o.write(self, section, value)
    local n = tonumber(value)
    if n ~= nil then
        return Value.write(self, section, n * 1024 *1024)
    end
end

o = s:option(Value, "keepalive", translate("keepalive"), translate("NAT keepalive interval(in seconds) to prevent your router from removing port mapping, default unit is seconds."))
o.datatype = "uinteger"
o.placeholder = "10"
o.rmempty = true

return m
