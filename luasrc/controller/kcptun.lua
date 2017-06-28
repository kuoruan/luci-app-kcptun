-- Copyright 2016-2017 Xingwang Liao <kuoruan@gmail.com>
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--	http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

module("luci.controller.kcptun", package.seeall)

local uci  = require "luci.model.uci".cursor()
local http = require "luci.http"
local fs   = require "nixio.fs"
local sys  = require "luci.sys"
local kcptun = "kcptun"
local default_log_folder = "/var/log/kcptun"

function index()
	if not nixio.fs.access("/etc/config/kcptun") then
		return
	end

	entry({"admin", "services", "kcptun"},
		alias("admin", "services", "kcptun", "overview"),
		_("Kcptun")).dependent = true

	entry({"admin", "services", "kcptun", "overview"},
		cbi("kcptun/overview"),
		_("Overview"), 10).leaf = true

	entry({"admin", "services", "kcptun", "settings"},
		cbi("kcptun/settings"),
		_("Settings"), 20).leaf = true

	entry({"admin", "services", "kcptun", "servers"},
			arcombine(cbi("kcptun/servers"), cbi("kcptun/servers-detail")),
			_("Servers Manage"), 30).leaf = true

	entry({"admin", "services", "kcptun", "info"}, call("kcptun_info"))

	entry({"admin", "services", "kcptun", "clear_log"}, call("action_clear_log")).leaf = true
end

local function get_log(file)
	if fs.access(file) then
		return sys.exec("tail -n 20 %s" %{file})
	end
	return "error"
end

local function clear_log(file)
	if fs.access(file) then
		fs.writefile(file, "")
		return 0
	end
	return 13
end

local function is_running(file)
	local file_name = file and file:match(".*/([^/]+)$") or ""

	if not file or file == "" then
		return false
	end
	return sys.call("pidof %s >/dev/null" %{file_name}) == 0
end

function kcptun_info()
	local client_file = uci:get_first(kcptun, "general", "client_file")
	local enable_logging = uci:get_first(kcptun, "general", "enable_logging") == "1"

	local info = {
		client = {
			running = is_running(client_file),
			log = ''
		},
		event = {
			log = ''
		}
	}

	if enable_logging then
		local log_folder = uci:get_first(kcptun, "general", "log_folder") or default_log_folder
		info.client.log = get_log("%s/client.log" %{log_folder})
		info.event.log = get_log("%s/event.log" %{log_folder})
	end

	http.prepare_content("application/json")
	http.write_json(info)
end

function action_clear_log(num)
	local id = num and tonumber(num) or 0

	local code = 0
		-- success - 0
		-- id required - 11
		-- error id - 12
		-- log file does not exist - 13

	if id > 0 then
		local log_folder = uci:get_first(kcptun, "general", "log_folder") or default_log_folder

		if id == 1 then
			code = clear_log("%s/client.log" %{log_folder})
		elseif id == 2 then
			code = clear_log("%s/event.log" %{log_folder})
		else
			code = 12
		end
	else
		code = 11
	end

	http.prepare_content("text/plain")
	http.write(tostring(code))
end
