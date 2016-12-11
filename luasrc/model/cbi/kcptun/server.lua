-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

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

m = Map(kcptun, "%s - %s" %{translate("Kcptun"), translate("Configuration")})
m.redirect = dsp.build_url("admin/services/kcptun/list")

if m.uci:get(kcptun, sid) ~= "server" then
    luci.http.redirect(m.redirect)
    return
end

s = m:section(NamedSection, sid, "server", translate("Server Manage"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "alias", "%s %s" %{translate("Alias"), translate("(optional)")})
o.rmempty = true

o = s:option(Value, "target", translate("Target"))
o.datatype = "host"
o.placeholder = "0.0.0.0"
o.default = "0.0.0.0"
o.rmempty = false

o = s:option(Value, "target_port", translate("Target Port"))
o.datatype = "port"
o.placeholder = "12948"
o.default = "12948"
o.rmempty = false

o = s:option(Value, "listen_host", "%s %s" %{translate("Listen Host"), translate("(optional)")}, translate("Server listen host."))
o.datatype = "host"
o.placeholder = "127.0.0.1"
o.rmempty = true

o = s:option(Value, "listen_port", translate("Listen Port"), translate("Server listen port."))
o.datatype = "port"
o.placeholder = "29900"
o.default = "29900"
o.rmempty = false

o = s:option(Value, "key", "%s %s" %{translate("Key"), translate("(optional)")}, translate("Pre-shared secret for client and server."))
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

o = s:option(Value, "mtu", "%s %s" %{translate("mtu"), translate("(optional)")}, translate("Maximum transmission unit of UDP packets."))
o.datatype = "and(uinteger, max(1500))"
o.placeholder = "1350"
o.rmempty = true

o = s:option(Value, "sndwnd", "%s %s" %{translate("sndwnd"), translate("(optional)")}, translate("Send Window Size(num of packets)."))
o.datatype = "uinteger"
o.placeholder = "128"
o.rmempty = true

o = s:option(Value, "rcvwnd", "%s %s" %{translate("rcvwnd"), translate("(optional)")}, translate("Receive Window Size(num of packets)."))
o.datatype = "uinteger"
o.placeholder = "1024"
o.rmempty = true

o = s:option(Value, "datashard", "%s %s" %{translate("datashard"), translate("(optional)")}, translate("Reed-solomon Erasure Coding - datashard."))
o.datatype = "uinteger"
o.placeholder = "10"
o.rmempty = true

o = s:option(Value, "parityshard", "%s %s" %{translate("parityshard"), translate("(optional)")}, translate("Reed-solomon Erasure Coding - parityshard."))
o.datatype = "uinteger"
o.placeholder = "3"
o.rmempty = true

o = s:option(Value, "dscp", "%s %s" %{translate("dscp"), translate("(optional)")}, translate("DSCP(6bit)"))
o.datatype = "uinteger"
o.placeholder = "0"
o.rmempty = true

o = s:option(Flag, "nocomp", translate("nocomp"), translate("Disable Compression?"))
o.enabled = "true"
o.disabled = "false"
o.default = o.disabled
o.rmempty = false

o = s:option(Flag, "nodelay", translate("nodelay"), translate("Enable nodelay Mode."))
o.enabled = "1"
o.disabled = "0"
o.rmempty = true
o:depends("mode", "manual")
function o.cfgvalue(self, section)
    return Flag.cfgvalue(self, section) or o.enabled
end

o = s:option(Value, "interval", translate("interval"))
o.datatype = "uinteger"
o.placeholder = "20"
o.rmempty = true
o:depends("mode", "manual")

o = s:option(ListValue, "resend", translate("resend"))
o:value("0", translate("Off"))
o:value("1", translate("On"))
o:value("2", translate("2nd ACK"))
o.default = "2"
o.rmempty = true
o:depends("mode", "manual")

o = s:option(Flag, "nc", translate("nc"))
o.enabled = "1"
o.disabled = "0"
o.rmempty = true
o:depends("mode", "manual")
function o.cfgvalue(self, section)
    return Flag.cfgvalue(self, section) or o.enabled
end

o = s:option(Flag, "acknodelay", translate("acknodelay"))
o.enabled = "true"
o.disabled = "false"
o.default = o.disabled
o.rmempty = true
o:depends("mode", "manual")

o = s:option(Value, "sockbuf", "%s %s" %{translate("sockbuf"), translate("(optional)")}, translate("Send/secv buffer size of udp sockets, default unit is MB."))
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

o = s:option(Value, "keepalive", "%s %s" %{translate("keepalive"), translate("(optional)")}, translate("NAT keepalive interval to prevent your router from removing port mapping, default unit is seconds."))
o.datatype = "uinteger"
o.placeholder = "10"
o.rmempty = true

return m
