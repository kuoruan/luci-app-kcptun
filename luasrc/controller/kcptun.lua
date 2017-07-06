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

module("luci.controller.kcptun", package.seeall)

local uci  = require "luci.model.uci".cursor()
local http = require "luci.http"
local fs   = require "nixio.fs"
local sys  = require "luci.sys"
local tpl  = require "luci.template"
local ipkg = require "luci.model.ipkg"
local kcptun = "kcptun"

local default_log_folder = "/var/log/kcptun"

function index()
	if not nixio.fs.access("/etc/config/kcptun") then
		return
	end

	entry({"admin", "services", "kcptun"},
		alias("admin", "services", "kcptun", "overview"),
		_("Kcptun Client")).dependent = true

	entry({"admin", "services", "kcptun", "overview"},
		call("action_overview"), _("Overview"), 10)

	entry({"admin", "services", "kcptun", "settings"},
		cbi("kcptun/settings"), _("Settings"), 20)

	entry({"admin", "services", "kcptun", "servers"},
		arcombine(cbi("kcptun/servers"), cbi("kcptun/servers-detail")),
		_("Server Manage"), 30).leaf = true

	entry({"admin", "services", "kcptun", "info"}, call("action_info"))

	entry({"admin", "services", "kcptun", "check"}, call("action_check")).leaf = true

	entry({"admin", "services", "kcptun", "update"}, call("action_update")).leaf = true

	entry({"admin", "services", "kcptun", "clear_log"}, call("action_clear_log")).leaf = true
end

local function get_log(file)
	if fs.access(file) then
		return sys.exec("tail -n 20 %s" %{file})
	end
	return "error"
end

local function is_running(file)
	local running = false
	local file_name = file and file:match(".*/([^/]+)$") or ""

	if file and file ~= "" then
		running = sys.call("pidof %s >/dev/null" %{file_name}) == 0
	end
	return running
end

local function get_version(type)
	if not type
		or type == ""
		or type == kcptun then
			type = "client"
	end

	local version
	if type == "client" then
		local client_file = uci:get_first(kcptun, "general", "client_file") or ""

		if client_file ~= "" and fs.access(client_file, "rwx", "rx", "rx") then
			version = sys.exec("%s -v | cut -d' ' -f3" %{client_file})
		end
	elseif type == "luci" then
		local package_name = "luci-app-kcptun"
		local package_info = ipkg.info(package_name) or {}

		if next(package_info) ~= nil then
			version = package_info[package_name]["Version"]
		end
	end

	return version or ""
end

local function compare_versions(ver1, comp, ver2)
	local table = table
	local util  = require "luci.util"

	local av1 = util.split(ver1, "[%.%-]", nil, true)
	local av2 = util.split(ver2, "[%.%-]", nil, true)

	local max = table.getn(av1)
	local n2 = table.getn(av2)
	if (max < n2) then
		max = n2
	end

	for i = 1, max, 1  do
		local s1 = av1[i] or ""
		local s2 = av2[i] or ""

		if comp == "~=" and (s1 ~= s2) then return true end
		if (comp == "<" or comp == "<=") and (s1 < s2) then return true end
		if (comp == ">" or comp == ">=") and (s1 > s2) then return true end
		if (s1 ~= s2) then return false end
	end

	return not (comp == "<" or comp == ">")
end

function action_overview()
	local enable_logging = uci:get_first(kcptun, "general", "enable_logging") == "1"
	local arch           = uci:get_first(kcptun, "general", "arch") or ""

	local values = {
		arch           = arch,
		client_version = get_version("client"),
		luci_version   = get_version("luci"),
		enable_logging = enable_logging
	}

	tpl.render("kcptun/overview", values)
end

function action_info()
	local client_file = uci:get_first(kcptun, "general", "client_file")
	local enable_logging = uci:get_first(kcptun, "general", "enable_logging") == "1"

	local info = {
		client = {
			running = is_running(client_file),
			log = ""
		},
		event = {
			log = ""
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

function action_check(type)
	if not type
		or type == ""
		or type == "client"
		or type == "server" then
		type = kcptun
	end

	local arch = http.formvalue("arch") or ""
	local obj

	local json = {
		code = 1,
		needs_update = false
	}

	local content = sys.exec("sh /usr/lib/%s/%s_update.sh check %s" %{ kcptun, type, arch })

	if content and content ~= "" then
		obj = luci.jsonc.parse(content)
	end

	if obj then
		json.code = obj.code

		if obj.version ~= "" then
			local old_version = get_version(type)
			json.needs_update = compare_versions(old_version, "<", obj.version)
			if json.needs_update then
				json.version = obj.version
				json.html_url = obj.html_url
			end
		end
	end

	http.prepare_content("application/json")
	http.write_json(json)
end

function action_update(type)
	if not type
		or type == ""
		or type == "client"
		or type == "server" then
		type = kcptun
	end

	local code = sys.call("sh /usr/lib/%s/%s_update.sh update %s" %{ kcptun, type, arch })

	http.prepare_content("text/plain")
	http.write(tostring(code))
end

function action_clear_log(type)
	local type = type or ""

	local code = 0
		-- success - 0
		-- error - 1

	if type ~= "" then
		local log_folder = uci:get_first(kcptun, "general", "log_folder")
		local log_file = "%s/%s.log" %{ log_folder or default_log_folder, type }
		if fs.access(log_file) then
			fs.writefile(log_file, "")
			code = 0
		else
			code = 1
		end
	else
		code = 1
	end

	http.prepare_content("text/plain")
	http.write(tostring(code))
end
