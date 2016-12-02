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

module("luci.controller.kcptun", package.seeall)

local uci  = require "luci.model.uci".cursor()
local http = require "luci.http"
local fs = require "nixio.fs"
local sys  = require "luci.sys"
local kcptun = "kcptun"

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

    entry({"admin", "services", "kcptun", "list"},
        cbi("kcptun/list"),
        _("Configuration List"), 30).leaf = true

    entry({"admin", "services", "kcptun", "client"},
        cbi("kcptun/client")).leaf = true

    entry({"admin", "services", "kcptun", "server"},
        cbi("kcptun/server")).leaf = true

    entry({"admin", "services", "kcptun", "info"}, call("kcptun_info"))

    entry({"admin", "services", "kcptun", "clear_log"}, post("action_clear_log")).leaf = true
end

function kcptun_info()

    local enable_server = uci:get_first(kcptun, "general", "enable_server") == "1"
    local enable_monitor = uci:get_first(kcptun, "general", "enable_monitor") == "1"
    local enable_logging = uci:get_first(kcptun, "general", "enable_logging") == "1"

    local client_file = uci:get_first(kcptun, "general", "client_file") or ""

    local info = {
        client = {
            running = false
        }
    }

    if client_file ~= "" then
        info.client.running = (sys.call("ps -w | grep -v grep | grep -q " .. client_file) == 0)
    end

    if enable_server then
        local server_file = uci:get_first(kcptun, "general", "server_file") or ""

        info.server = {
            running = false
        }

        if server_file ~= "" then
            info.server.running = (sys.call("ps -w | grep -v grep | grep -q " .. server_file) == 0)
        end
    end

    if enable_logging then
        local log_folder = uci:get_first(kcptun, "general", "log_folder") or ""

        if log_folder ~= "" then
            local client_log_file = log_folder .. "/kcptun-client.log"
            if fs.access(client_log_file) then
                info.client.log = sys.exec("tail -n 20 " .. client_log_file)
            else
                info.client.log = "error"
            end

            if enable_server then
                local server_log_file = log_folder .. "/kcptun-server.log"
                if fs.access(server_log_file) then
                    info.server.log = sys.exec("tail -n 20 " .. server_log_file)
                else
                    info.server.log = "error"
                end
            end

            if enable_monitor then
                local monitor_log_file = log_folder .. "/kcptun-monitor.log"
                if fs.access(monitor_log_file) then
                    info.monitor.log = sys.exec("tail -n 20 " .. monitor_log_file)
                else
                    info.monitor.log = "error"
                end
            end
        else
            info.client.log = "error"
            info.server.log = "error"
            info.monitor.log = "error"
        end
    end

    http.prepare_content("application/json")
    http.write_json(info)
end

function action_clear_log(num)
    local id = tonumber(num or 0)

    local log_file
    local log_folder = uci:get_first(kcptun, "general", "log_folder") or ""
    local code = 0
        -- success - 0
        -- id required - 11
        -- error id - 12
        -- log file does not exist - 13

    if id > 0 and log_folder ~= "" then
        if id == 1 then
            log_file = log_folder .. "/kcptun-client.log"
        elseif id == 2 then
            log_file = log_folder .. "/kcptun-server.log"
        elseif id ==3 then
            log_file = log_folder .. "/kcptun-monitor.log"
        else
            code = 12
        end

        if log_file and fs.access(log_file) then
            fs.writefile(log_file, "")
        else
            code = 13
        end
    else
        code = 11
    end

    http.prepare_content("text/plain")
    http.write(tostring(code))
end
