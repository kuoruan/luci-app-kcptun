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
local util = require "luci.util"
local sys = require "luci.sys"
local fs = require "nixio.fs"

local m, s, o, enable_server, enable_logging
local kcptun = "kcptun"
local default_client_file = "/usr/bin/kcptun/client"
local default_server_file = "/usr/bin/kcptun/server"
local default_log_folder = "/var/log/kcptun"
local client_table = {}
local server_table = {}

local function get_ip_string(ip)
    if ip and ip:find(":") then
        return "[%s]" %{ip}
    else
        return ip or ""
    end
end

uci:foreach(kcptun, "client", function(c)
    if c.alias then
        client_table[c[".name"]] = c.alias
    elseif c.server and c.server_port then
        client_table[c[".name"]] = "%s:%s" %{get_ip_string(c.server), c.server_port}
    end
end)

uci:foreach(kcptun, "server", function(s)
    if s.alias then
        server_table[s[".name"]] = s.alias
    elseif s.target and s.target_port then
        server_table[s[".name"]] = "%s:%s" %{get_ip_string(s.target), s.target_port}
    end
end)

local function isKcptun(file)
    if not fs.access(file, "rwx", "rx", "rx") then
        fs.chmod(file, 755)
    end

    local str = sys.exec(file .. " -v | awk '{printf $1}'")
    return (str:lower() == "kcptun")
end

m = Map(kcptun, "%s - %s" %{translate("Kcptun"), translate("Settings")})

s = m:section(TypedSection, "general", translate("General Settings"))
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "kcptun_client", translate("Kcptun Client"))
o:value("nil", translate("Disable"))
for k, v in pairs(client_table) do
    o:value(k, v)
end
o.default = "nil"
o.rmempty = false

o = s:option(Value, "client_file", translate("Client Exec File"))
o.datatype = "file"
o.placeholder = default_client_file
o.rmempty = false
function o.validate(self, value, section)
    if value and fs.access(value) and not isKcptun(value) then
        return nil, translate("Not a Kcptun executable file.")
    end

    return value
end

enable_server = s:option(Flag, "enable_server", translate("Enable Server"))
enable_server.enabled = "1"
enable_server.disabled = "0"
enable_server.default = o.disabled
enable_server.rmempty = false

o = s:option(ListValue, "kcptun_server", translate("Kcptun Server"))
o:value("nil", translate("Disable"))
for k, v in pairs(server_table) do
    o:value(k, v)
end
o.default = "nil"
o:depends("enable_server", "1")

o = s:option(Value, "server_file", translate("Server Exec File"))
o.datatype = "file"
o.placeholder = default_server_file
o:depends("enable_server", "1")
o.rmempty = true
function o.formvalue(self, section)
    local enable = enable_server:formvalue(section) or enable_server.disabled
    local value = (Value.formvalue(self, section) or ""):trim()

    if enable == enable_server.enabled and value == "" then
        return "-"
    end

    return value
end
function o.validate(self, value, section)
    if value == "-" then
        return nil, translate("Server exec file required.")
    end

    if fs.access(value) and not isKcptun(value) then
       return nil, translate("Not a Kcptun executable file.")
    end

    return value
end

o = s:option(ListValue, "daemon_user", translate("Run daemon as user"))
local p_user
for _, p_user in util.vspairs(util.split(sys.exec("cat /etc/passwd | cut -f 1 -d :"))) do
    o:value(p_user)
end

o = s:option(Flag, "enable_monitor", translate("Enable Process Monitor"), translate("Check Kcptun process per minute."))
o.enabled = "1"
o.disabled = "0"
o.default = o.disabled
o.rmempty = false

o = s:option(Flag, "enable_auto_restart", translate("Enable Timed Restart Task"), translate("Restart Kcptun at 5 in the morning."))
o.enabled = "1"
o.disabled = "0"
o.default = o.disabled
o.rmempty = false

enable_logging = s:option(Flag, "enable_logging", translate("Enable Logging"))
enable_logging.enabled = "1"
enable_logging.disabled = "0"
enable_logging.default = enable_logging.disabled
enable_logging.rmempty = false

o = s:option(Value, "log_folder", translate("Log Folder"))
o.datatype = "directory"
o.default = default_log_folder
o.placeholder = default_log_folder
o:depends("enable_logging", "1")
o.rmempty = true
function o.formvalue(self, section)
    local value = (Value.formvalue(self, section) or ""):trim()
    if value ~= "" then

        value = string.gsub(value, "\\", "/")
        if value:sub(1, 1) ~= "/" then
            value = "/" .. value
        end

        while value:sub(-1) == "/" do
            value = value:sub(1, -2)
        end
    end

    return value
end
function o.validate(self, value, section)
    if value and not fs.stat(value) then
        local res, code, msg = fs.mkdir(value)
        if not res then
            return nil, msg
        end
    end
    return Value.validate(self, value, section)
end

return m
