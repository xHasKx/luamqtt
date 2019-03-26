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
]]

-- module table
local ioloop = {}

-- load required stuff
local ipairs = ipairs
local require = require
local tbl_remove = table.remove

-- ioloop instances metatable
local ioloop_mt = {}
ioloop_mt.__index = ioloop_mt

-- Initialize ioloop instance, opts described in ioloop.create(opts)
function ioloop_mt:init(opts) -- TODO: opts ==> args
	opts = opts or {}
	opts.timeout = opts.timeout or 0.01
	opts.sleep = opts.sleep or 0
	opts.sleep_function = opts.sleep_function or require("socket").sleep
	self.opts = opts
	self.clients = {}
	self.running = false
end

-- Add mqtt client to the ioloop instance
-- Returns true on success, or false plus error message on failure (such client is already added to ioloop)
function ioloop_mt:add(client)
	local clients = self.clients
	if clients[client] then
		return false, "such MQTT client is already added to this ioloop"
	end
	clients[#clients + 1] = client
	clients[client] = #clients

	-- associate ioloop with adding MQTT client
	client:set_ioloop(self)

	return true
end

-- Remove mqtt client from the ioloop instance
-- Returns true on success, or false plus error message on failure (no such client was added to ioloop)
function ioloop_mt:remove(client)
	local clients = self.clients
	local idx = clients[client]
	if not idx then
		return false, "no such MQTT client was added to ioloop"
	end
	clients[client] = nil
	tbl_remove(clients, idx)
	return true
end

-- Perform one ioloop iteration
function ioloop_mt:iteration()
	self.timeouted = false
	for _, client in ipairs(self.clients) do
		client:_ioloop_iteration()
	end
	-- sleep a bit
	local opts = self.opts
	local sleep = opts.sleep
	if sleep > 0 then
		opts.sleep_function(sleep)
	end
end

-- Perform sleep if no one of the network operation in current iteration was not timeouted
function ioloop_mt:can_sleep()
	if not self.timeouted then
		local opts = self.opts
		opts.sleep_function(opts.timeout)
		self.timeouted = true
	end
end

-- Run ioloop until at least one client are in ioloop
function ioloop_mt:run_until_clients()
	self.running = true
	while next(self.clients) do
		self:iteration()
	end
	self.running = false
end

-------

-- Create IO loop instance with given options
-- opts: a table with such fields
-- {
--		timeout = 0.01,								-- default timeout for socket blocking operations
--		sleep = 0, 									-- default sleep timeout when no socket operations was performed, to prevent high CPU usage on idle
--		sleep_function = require("socket").sleep	-- sleep function to be runned at the end of all ioloop iterations, if opts.sleep > 0
-- }
local function ioloop_create(opts)
	local inst = setmetatable({}, ioloop_mt)
	inst:init(opts)
	return inst
end
ioloop.create = ioloop_create

-- Default ioloop instance
local ioloop_instance

-- Returns default ioloop instance
function ioloop.get()
	if not ioloop_instance then
		ioloop_instance = ioloop_create()
	end
	return ioloop_instance
end

-------

-- export module table
return ioloop

-- vim: ts=4 sts=4 sw=4 noet ft=lua
