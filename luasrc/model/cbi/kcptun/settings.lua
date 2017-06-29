-- Copyright 2016-2017 Xingwang Liao <kuoruan@gmail.com>
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

local uci  = require "luci.model.uci".cursor()
local util = require "luci.util"
local sys  = require "luci.sys"
local fs   = require "nixio.fs"

local m, s, o
local kcptun = "kcptun"
local server_table = {}
local default_client_file = "/usr/bin/kcptun/client"
local default_log_folder  = "/var/log/kcptun"

local function get_ip_string(ip)
	if ip and ip:find(":") then
		return "[%s]" %{ip}
	else
		return ip or ""
	end
end

uci:foreach(kcptun, "servers", function(s)
	if s.alias then
		server_table[s[".name"]] = s.alias
	elseif s.server_addr and s.server_port then
		server_table[s[".name"]] = "%s:%s" %{get_ip_string(s.server_addr), s.server_port}
	end
end)

local function is_kcptun(file)
	if not fs.access(file, "rwx", "rx", "rx") then
		fs.chmod(file, 755)
	end

	return sys.call("%s -v | grep -q '%s'" %{file, kcptun}) == 0
end

local function time_validator(self, value, desc)
	if value ~= nil then
		local h_str, m_str = value:match("^(%d%d?):(%d%d?)$")
		local h = tonumber(h_str)
		local m = tonumber(m_str)
		if ( h ~= nil and
			 h >= 0   and
			 h <= 23  and
			 m ~= nil and
			 m >= 0   and
			 m <= 59) then
			return value
		end
	end
	return nil, translatef("The value '%s' is invalid.", desc)
end

m = Map(kcptun, "%s - %s" %{translate("Kcptun"), translate("Settings")})

s = m:section(TypedSection, "general", translate("General Settings"))
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "server", translate("Server"))
o:value("nil", translate("Disable"))
for k, v in pairs(server_table) do
	o:value(k, v)
end
o.default = "nil"
o.rmempty = false

o = s:option(Value, "client_file", translate("Client Exec File"))
o.datatype = "file"
o.placeholder = default_client_file
o.rmempty = false
o.validate = function(self, value, section)
	if value and fs.access(value) and not is_kcptun(value) then
		return nil, translate("Not a Kcptun executable file.")
	end

	return value
end

o = s:option(ListValue, "daemon_user", translate("Run daemon as user"))
local p_user
for _, p_user in util.vspairs(util.split(sys.exec("cat /etc/passwd | cut -d':' -f1"))) do
	o:value(p_user)
end

o = s:option(Flag, "enable_logging", translate("Enable Logging"))
o.enabled = "1"
o.disabled = "0"
o.default = o.disabled
o.rmempty = false

o = s:option(Value, "log_folder", translate("Log Folder"))
o.datatype = "directory"
o.default = default_log_folder
o.placeholder = default_log_folder
o:depends("enable_logging", "1")
o.formvalue = function(...)
	local v = (Value.formvalue(...) or ""):trim()
	if v ~= "" then
		v = string.gsub(v, "\\", "/")
		if v:sub(1, 1) ~= "/" then
			v = "/" .. v
		end

		while v:sub(-1) == "/" do
			v = v:sub(1, -2)
		end
	end

	return v
end
o.validate = function(self, value, section)
	if value and not fs.stat(value) then
		local res, code, msg = fs.mkdir(value)
		if not res then
			return nil, msg
		end
	end
	return Value.validate(self, value, section)
end

o = s:option(Value, "auto_restart", translate("Auto Restart Service"))
o:value("", translate("Off"))
o:value("00:00")
o:value("01:00")
o:value("02:00")
o:value("03:00")
o:value("04:00")
o:value("05:00")
o:value("06:00")
o:value("07:00")
o:value("08:00")
o:value("09:00")
o:value("10:00")
o:value("11:00")
o:value("12:00")
o:value("13:00")
o:value("14:00")
o:value("15:00")
o:value("16:00")
o:value("17:00")
o:value("18:00")
o:value("19:00")
o:value("20:00")
o:value("21:00")
o:value("22:00")
o:value("23:00")
o.validate = function(self, value, section)
	return time_validator(self, value, translate("Restart Time"))
end

return m
