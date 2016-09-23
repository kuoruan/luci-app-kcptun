-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs = require "nixio.fs"

local m, s, o
local kcptun = "kcptun"

m = SimpleForm(kcptun, "%s - %s" %{translate("Kcptun"), translate("Overview")})
m:append(Template("kcptun/status"))
m.reset = false
m.submit = false

if uci:get_first(kcptun, "general", "enable_logging") == "1" then
    local log_folder = uci:get_first(kcptun, "general", "log_folder")

    s = m:section(SimpleSection, translate("Client Log"))

    o = s:option(TextValue, "_client_log")
    o.rows = 21
    o.readonly = true
    o.resize = "none"
    function o.cfgvalue()
        local client_log = log_folder .. "/kcptun-client.log"
        local str = sys.exec("tail -n 20 " .. client_log)
        return str:len() > 0 and str or translate("No log data...")
    end

    if uci:get_first(kcptun, "general", "enable_server") == "1" then

        s = m:section(SimpleSection, translate("Server Log"))
        o = s:option(TextValue, "_server_log")
        o.rows = 21
        o.readonly = true
        o.resize = "none"
        function o.cfgvalue()
            local server_log = log_folder .. "/kcptun-server.log"
            local str = sys.exec("tail -n 20 " .. server_log)
            return str:len() > 0 and str or translate("No log data...")
        end

    end
end

return m
