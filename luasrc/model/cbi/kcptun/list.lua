-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"
local http = require "luci.http"

local m, s, o
local kcptun = "kcptun"

m = Map(kcptun, "%s - %s" %{translate("Kcptun"), translate("Configuration List")})

s = m:section(TypedSection, "client", translate("Clients List"))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"
s.extedit = dsp.build_url("admin/services/kcptun/client/%s")
function s.create(...)
    local sid = TypedSection.create(...)
    if sid then
        http.redirect(s.extedit % sid)
        return
    end
end

o = s:option(DummyValue, "alias", "Alias")
function o.cfgvalue(self, section)
    return Value.cfgvalue(self, section) or translate("None")
end

o = s:option(DummyValue, "_server_address", translate("Server Address"))
function o.cfgvalue(self, section)
    local ip = m.uci:get(kcptun, section, "server_ip")
    local port = m.uci:get(kcptun, section, "server_port")

    if ip and port then
        return "%s:%s" %{ip, port}
    end

    return "?"
end

o = s:option(DummyValue, "local_port", translate("Local Port"))
function o.cfgvalue(...)
    local v = Value.cfgvalue(...)
    return v or "?"
end

o = s:option(DummyValue, "crypt", translate("Encrypt Method"))
function o.cfgvalue(...)
    local v = Value.cfgvalue(...)
    return v and v:upper() or "?"
end

o = s:option(DummyValue, "mode", translate("Embedded Mode"))
function o.cfgvalue(...)
    local v = Value.cfgvalue(...)
    return v and v:upper() or "?"
end

o = s:option(DummyValue, "nocomp", translate("Disable Compression"))
function o.cfgvalue(...)
    local v = Value.cfgvalue(...)
    return v and translate(v:gsub("^%l", string.upper)) or translate("False") --First character uppercase
end

if uci:get_first(kcptun, "general", "enable_server") == "1" then

    s = m:section(TypedSection, "server", translate("Servers List"))
    s.anonymous = true
    s.addremove = true
    s.template = "cbi/tblsection"
    s.extedit = dsp.build_url("admin/services/kcptun/server/%s")
    function s.create(...)
        local sid = TypedSection.create(...)
        if sid then
            http.redirect(s.extedit % sid)
            return
        end
    end

    o = s:option(DummyValue, "alias", "Alias")
    function o.cfgvalue(self, section)
        return Value.cfgvalue(self, section) or translate("None")
    end

    o = s:option(DummyValue, "_target_address", translate("Target Address"))
    function o.cfgvalue(self, section)
        local ip = m.uci:get(kcptun, section, "target_ip")
        local port = m.uci:get(kcptun, section, "target_port")

        if ip and port then
            return "%s:%s" %{ip, port}
        end

        return "?"
    end

    o = s:option(DummyValue, "listen_port", translate("Listen Port"))
    function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
        return v or "?"
    end

    o = s:option(DummyValue, "crypt", translate("Encrypt Method"))
    function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
        return v and v:upper() or "?"
    end

    o = s:option(DummyValue, "mode", translate("Embedded Mode"))
    function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
        return v and v:upper() or "?"
    end

    o = s:option(DummyValue, "nocomp", translate("Disable Compression"))
    function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
        return v and translate(v:gsub("^%l", string.upper)) or translate("False")
    end

end

return m
