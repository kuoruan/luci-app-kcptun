-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

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
    local enable_logging = uci:get_first(kcptun, "general", "enable_logging") == "1"
    local log_folder = uci:get_first(kcptun, "general", "log_folder") or ""

    local info = {
        client = {
            running = false
        }
    }

    local client_pid = tonumber(fs.readfile("/var/run/kcptun/client.pid") or 0)
    if client_pid > 0 then
        info.client.running = (sys.call("ps | awk '{print $1}' | grep -q " .. client_pid) == 0)
    end

    if enable_logging and log_folder ~= "" then
        local client_log_file = log_folder .. "/kcptun-client.log"
        if fs.access(client_log_file) then
            info.client.log = sys.exec("tail -n 20 " .. client_log_file)
        else
            info.client.log = "error"
        end
    end

    if enable_server then
        info.server = {
            running = false
        }
        local server_pid = tonumber(fs.readfile("/var/run/kcptun/server.pid") or 0)
        if server_pid > 0 then
            info.server.running = (sys.call("ps | awk '{print $1}' | grep -q " .. server_pid) == 0)
        end

        if enable_logging and log_folder ~= "" then
            local server_log_file = log_folder .. "/kcptun-server.log"
            if fs.access(server_log_file) then
                info.server.log = sys.exec("tail -n 20 " .. server_log_file)
            else
                info.server.log = "error"
            end
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
