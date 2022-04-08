--- MQTT module
-- @module mqtt

--[[
MQTT protocol DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

CONVENTIONS:

	* errors:
		* passing invalid arguments (like number instead of string) to function in this library will raise exception
		* all other errors will be returned in format: false, "error-text"
			* you can wrap function call into standard lua assert() to raise exception

]]

--- Module table
-- @field v311 MQTT v3.1.1 protocol version constant
-- @field v50  MQTT v5.0   protocol version constant
-- @field _VERSION luamqtt version string
-- @table mqtt
local mqtt = {
	-- supported MQTT protocol versions
	v311 = 4,		-- supported protocol version, MQTT v3.1.1
	v50 = 5,		-- supported protocol version, MQTT v5.0

	-- mqtt library version
	_VERSION = "3.4.2",
}

-- load required stuff
local type = type
local select = select
local require = require

local client = require("mqtt.client")
local client_create = client.create

local ioloop_get = require("mqtt.ioloop").get

--- Create new MQTT client instance
-- @param ... Same as for mqtt.client.create(...)
-- @see mqtt.client.client_mt:__init
function mqtt.client(...)
	return client_create(...)
end

--- Returns default ioloop instance
-- @function mqtt.get_ioloop
mqtt.get_ioloop = ioloop_get

--- Run default ioloop for given MQTT clients or functions
-- @param ... MQTT clients or lopp functions to add to ioloop
-- @see mqtt.ioloop.get
-- @see mqtt.ioloop.run_until_clients
function mqtt.run_ioloop(...)
	local loop = ioloop_get()
	for i = 1, select("#", ...) do
		local cl = select(i, ...)
		loop:add(cl)
		if type(cl) ~= "function" then
			cl:start_connecting()
		end
	end
	return loop:run_until_clients()
end

--- Run synchronous input/output loop for only one given MQTT client.
-- Provided client's connection will be opened.
-- Client reconnect feature will not work, and keep_alive too.
-- @param cl MQTT client instance to run
function mqtt.run_sync(cl)
	local ok, err = cl:start_connecting()
	if not ok then
		return false, err
	end
	while cl.connection do
		ok, err = cl:_sync_iteration()
		if not ok then
			return false, err
		end
	end
end

-- export module table
return mqtt

-- vim: ts=4 sts=4 sw=4 noet ft=lua
