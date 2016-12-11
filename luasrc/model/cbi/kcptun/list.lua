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
local dsp = require "luci.dispatcher"
local http = require "luci.http"

local m, clients_list, servers_list, o
local kcptun = "kcptun"

local function get_ip_string(ip)
    if ip and ip:find(":") then
        return "[%s]" %{ip}
    else
        return ip or ""
    end
end

m = Map(kcptun, "%s - %s" %{translate("Kcptun"), translate("Configuration List")})

clients_list = m:section(TypedSection, "client", translate("Clients List"))
clients_list.anonymous = true
clients_list.addremove = true
clients_list.sortable = true
clients_list.template = "cbi/tblsection"
clients_list.extedit = dsp.build_url("admin/services/kcptun/client/%s")
function clients_list.create(...)
    local sid = TypedSection.create(...)
    if sid then
        http.redirect(clients_list.extedit % sid)
        return
    end
end

o = clients_list:option(DummyValue, "alias", translate("Alias"))
function o.cfgvalue(self, section)
    return Value.cfgvalue(self, section) or translate("None")
end

o = clients_list:option(DummyValue, "_server_address", translate("Server Address"))
function o.cfgvalue(self, section)
    local server = m.uci:get(kcptun, section, "server") or "?"
    local server_port = m.uci:get(kcptun, section, "server_port") or "?"
    return "%s:%s" %{get_ip_string(server), server_port}
end

o = clients_list:option(DummyValue, "_local_addres", translate("Local Listen"))
function o.cfgvalue(self, section)
    local local_host = m.uci.get(kcptun, section, "local_host") or ""
    local local_port = m.uci.get(kcptun, section, "local_port") or "?"
    return "%s:%s" %{get_ip_string(local_host), local_port}
end

o = clients_list:option(DummyValue, "crypt", translate("Encrypt Method"))
function o.cfgvalue(...)
    local v = Value.cfgvalue(...)
    return v and v:upper() or "?"
end

o = clients_list:option(DummyValue, "mode", translate("Embedded Mode"))
function o.cfgvalue(...)
    local v = Value.cfgvalue(...)
    return v and v:upper() or "?"
end

o = clients_list:option(DummyValue, "nocomp", translate("Disable Compression"))
function o.cfgvalue(...)
    local v = Value.cfgvalue(...)
    return v and translate(v:gsub("^%l", string.upper)) or translate("False") --First character uppercase
end

if uci:get_first(kcptun, "general", "enable_server") == "1" then

    servers_list = m:section(TypedSection, "server", translate("Servers List"))
    servers_list.anonymous = true
    servers_list.addremove = true
    servers_list.sortable = true
    servers_list.template = "cbi/tblsection"
    servers_list.extedit = dsp.build_url("admin/services/kcptun/server/%s")
    function servers_list.create(...)
        local sid = TypedSection.create(...)
        if sid then
            http.redirect(servers_list.extedit % sid)
            return
        end
    end

    o = servers_list:option(DummyValue, "alias", translate("Alias"))
    function o.cfgvalue(self, section)
        return Value.cfgvalue(self, section) or translate("None")
    end

    o = servers_list:option(DummyValue, "_target_address", translate("Target Address"))
    function o.cfgvalue(self, section)
        local target = m.uci:get(kcptun, section, "target") or "?"
        local target_port = m.uci:get(kcptun, section, "target_port") or "?"
        return "%s:%s" %{get_ip_string(target), target_port}
    end

    o = servers_list:option(DummyValue, "_listen_address", translate("Listen Address"))
    function o.cfgvalue(self, section)
        local listen_host = m.uci:get(kcptun, section, "listen_host") or ""
        local listen_port = m.uci:get(kcptun, section, "listen_port") or "?"
        return "%s:%s" %{get_ip_string(listen_host), listen_port}
    end

    o = servers_list:option(DummyValue, "crypt", translate("Encrypt Method"))
    function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
        return v and v:upper() or "?"
    end

    o = servers_list:option(DummyValue, "mode", translate("Embedded Mode"))
    function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
        return v and v:upper() or "?"
    end

    o = servers_list:option(DummyValue, "nocomp", translate("Disable Compression"))
    function o.cfgvalue(...)
        local v = Value.cfgvalue(...)
        return v and translate(v:gsub("^%l", string.upper)) or translate("False")
    end

end

return m
