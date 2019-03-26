--- MQTT module
-- @module mqtt

--[[
MQTT protocol DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

CONVENTIONS:

	* errors:
		* passing invalid arguments to function in this library will raise exception
		* all other errors will be returned in format: false, "error-text"
			* you can wrap function call into standard lua assert() to raise exception

]]

--- Module table
-- @table mqtt
-- @field _VERSION		library version
local mqtt = {
	-- supported MQTT protocol versions
	protocol_version = {
		"3.1.1",
	},
	-- mqtt library version
	_VERSION = "2.0.0",
}

-- load required stuff
local require = require
local client = require("mqtt.client")
local client_create = client.create
local ioloop_get = require("mqtt.ioloop").get
local select = select

--- Create new MQTT client instance
-- @param ... Same as for mqtt.client.create(...)
-- @see mqtt.client.client_mt:__init
function mqtt.client(...)
	return client_create(...)
end

--- Run default ioloop for given MQTT clients
-- @see mqtt.ioloop.get
-- @see mqtt.ioloop.run_until_clients
function mqtt.run_ioloop(...)
	local loop = ioloop_get()
	for i = 1, select("#", ...) do
		loop:add(select(i, ...))
	end
	return loop:run_until_clients()
end

-- export module table
return mqtt

-- vim: ts=4 sts=4 sw=4 noet ft=lua
