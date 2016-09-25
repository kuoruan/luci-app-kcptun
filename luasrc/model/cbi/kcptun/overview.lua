-- Copyright 2016 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs = require "nixio.fs"

local m, s, o
local kcptun = "kcptun"

m = SimpleForm(kcptun, "%s - %s" %{translate("Kcptun"), translate("Overview")})
m:append(Template("kcptun/overview"))
m.reset = false
m.submit = false

return m
