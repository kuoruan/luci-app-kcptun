-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.kcptun", package.seeall)

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

    entry({"admin", "services", "kcptun", "status"}, call("status"))
end

function status()
    local sys  = require "luci.sys"
    local uci  = require "luci.model.uci".cursor()
    local http = require "luci.http"
    local fs = require "nixio.fs"

    local status = {
        client = {
            version = 0,
            running = false
        },
        server = {
            enabled = (uci:get_first("kcptun", "general", "enable_server") == "1"),
            version = 0,
            running = false
        }
    }

    local client_file = uci:get_first("kcptun", "general", "client_file") or ""
    if client_file:trim() ~= "" then
        if fs.access(client_file, "rwx", "rx", "rx") then
            status.client.version = tostring(sys.exec(client_file .. " -v | awk '{printf $3}'") or 0)
        end
    end

    local client_pid = tonumber(fs.readfile("/var/run/kcptun/client.pid") or 0)
    if client_pid > 0 then
        status.client.running = (sys.call("ps | awk '{print $1}' | grep -q " .. client_pid) == 0)
    end

    if status.server.enabled then
        local server_file = uci:get_first("kcptun", "general", "server_file") or ""
        if server_file:trim() ~= "" then
            if fs.access(server_file, "rwx", "rx", "rx") then
                status.server.version = tostring(sys.exec(server_file .. " -v | awk '{printf $3}'") or 0)
            end
        end

        local server_pid = tonumber(fs.readfile("/var/run/kcptun/server.pid") or 0)
        if server_pid > 0 then
            status.server.running = (sys.call("ps | awk '{print $1}' | grep -q " .. server_pid) == 0)
        end
    end

    http.prepare_content("application/json")
    http.write_json(status)
end
