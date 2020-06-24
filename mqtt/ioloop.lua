--- ioloop module
-- @module mqtt.ioloop
-- @alias ioloop

--[[
	ioloop module

	In short: allowing you to work with several MQTT clients in one script, and allowing them to maintain
	a long-term connection to broker, using PINGs.

	NOTE: this module will work only with MQTT clients using standard luasocket/luasocket_ssl connectors.

	In long:
	Providing an IO loop instance dealing with efficient (as much as possible in limited lua IO) network communication
	for several MQTT clients in the same OS thread.
	The main idea is that you are creating an ioloop instance, then adding created and connected MQTT clients to it.
	The ioloop instance is setting a non-blocking mode for sockets in MQTT clients and setting a small timeout
	for their receive/send operations. Then ioloop is starting an endless loop trying to receive/send data for all added MQTT clients.
	You may add more or remove some MQTT clients from the ioloop after it's created and started.

	Using that ioloop is allowing you to run a MQTT client for long time, through sending PINGREQ packets to broker
	in keepAlive interval to maintain long-term connection.

	Also, any function can be added to the ioloop instance, and it will be called in the same endless loop over and over
	alongside with added MQTT clients to provide you a piece of processor time to run your own logic (like running your own
	network communications or any other thing good working in an io-loop)
]]

-- module table
local ioloop = {}

-- load required stuff
local next = next
local type = type
local ipairs = ipairs
local require = require
local setmetatable = setmetatable

local table = require("table")
local tbl_remove = table.remove

--- ioloop instances metatable
-- @type ioloop_mt
local ioloop_mt = {}
ioloop_mt.__index = ioloop_mt

--- Initialize ioloop instance
-- @tparam table args							ioloop creation arguments table
-- @tparam[opt=0.005] number args.timeout		network operations timeout in seconds
-- @tparam[opt=0] number args.sleep				sleep interval after each iteration
-- @tparam[opt] function args.sleep_function	custom sleep function to call after each iteration
-- @treturn ioloop_mt ioloop instance
function ioloop_mt:__init(args)
	args = args or {}
	args.timeout = args.timeout or 0.005
	args.sleep = args.sleep or 0
	args.sleep_function = args.sleep_function or require("socket").sleep
	self.args = args
	self.clients = {}
	self.running = false --ioloop running flag, used by MQTT clients which are adding after this ioloop started to run
end

--- Add MQTT client or a loop function to the ioloop instance
-- @tparam client_mt|function client		MQTT client or a loop function to add to ioloop
-- @return true on success or false and error message on failure
function ioloop_mt:add(client)
	local clients = self.clients
	if clients[client] then
		return false, "such MQTT client or loop function is already added to this ioloop"
	end
	clients[#clients + 1] = client
	clients[client] = true

	-- associate ioloop with adding MQTT client
	if type(client) ~= "function" then
		client:set_ioloop(self)
	end

	return true
end

--- Remove MQTT client or a loop function from the ioloop instance
-- @tparam client_mt|function client		MQTT client or a loop function to remove from ioloop
-- @return true on success or false and error message on failure
function ioloop_mt:remove(client)
	local clients = self.clients
	if not clients[client] then
		return false, "no such MQTT client or loop function was added to ioloop"
	end
	clients[client] = nil

	-- search an index of client to remove
	for i, item in ipairs(clients) do
		if item == client then
			tbl_remove(clients, i)
			break
		end
	end

	-- unlink ioloop from MQTT client
	if type(client) ~= "function" then
		client:set_ioloop(nil)
	end

	return true
end

--- Perform one ioloop iteration
function ioloop_mt:iteration()
	self.timeouted = false
	for _, client in ipairs(self.clients) do
		if type(client) ~= "function" then
			client:_ioloop_iteration()
		else
			client()
		end
	end
	-- sleep a bit
	local args = self.args
	local sleep = args.sleep
	if sleep > 0 then
		args.sleep_function(sleep)
	end
end

--- Perform sleep if no one of the network operation in current iteration was not timeouted
function ioloop_mt:can_sleep()
	if not self.timeouted then
		local args = self.args
		args.sleep_function(args.timeout)
		self.timeouted = true
	end
end

--- Run ioloop until at least one client are in ioloop
function ioloop_mt:run_until_clients()
	self.running = true
	while next(self.clients) do
		self:iteration()
	end
	self.running = false
end

-------

--- Create IO loop instance with given options
-- @see ioloop_mt:__init
-- @treturn ioloop_mt ioloop instance
local function ioloop_create(args)
	local inst = setmetatable({}, ioloop_mt)
	inst:__init(args)
	return inst
end
ioloop.create = ioloop_create

-- Default ioloop instance
local ioloop_instance

--- Returns default ioloop instance
-- @tparam[opt=true] boolean autocreate Automatically create ioloop instance
-- @tparam[opt] table args Arguments for creating ioloop instance
-- @treturn ioloop_mt ioloop instance
function ioloop.get(autocreate, args)
	if autocreate == nil then
		autocreate = true
	end
	if autocreate then
		if not ioloop_instance then
			ioloop_instance = ioloop_create(args)
		end
	end
	return ioloop_instance
end

-------

-- export module table
return ioloop

-- vim: ts=4 sts=4 sw=4 noet ft=lua
