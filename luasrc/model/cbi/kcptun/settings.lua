-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs = require "nixio.fs"

local m, s, o, enable_server, enable_logging
local kcptun = "kcptun"
local default_client_file = "/usr/bin/kcptun/client"
local default_server_file = "/usr/bin/kcptun/server"
local default_log_folder = "/var/log/kcptun"
local client_table = {}
local server_table = {}

uci:foreach(kcptun, "client", function(c)
    if c.alias then
        client_table[c[".name"]] = c.alias
    elseif c.server_ip and c.server_port then
        client_table[c[".name"]] = "%s:%s" %{c.server_ip, c.server_port}
    end
end)

uci:foreach(kcptun, "server", function(s)
    if s.alias then
        server_table[s[".name"]] = s.alias
    elseif s.target_ip and s.target_port then
        server_table[s[".name"]] = "%s:%s" %{s.target_ip, s.target_port}
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

enable_logging = s:option(Flag, "enable_logging", translate("Enable Logging"))
enable_logging.enabled = "1"
enable_logging.disabled = "0"
enable_logging.default = o.disabled
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
