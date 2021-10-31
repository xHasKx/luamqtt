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
local log = require "mqtt.log"
local next = next
local type = type
local ipairs = ipairs
local require = require
local setmetatable = setmetatable

local table = require("table")
local tbl_remove = table.remove

local math = require("math")
local math_min = math.min

--- ioloop instances metatable
-- @type ioloop_mt
local ioloop_mt = {}
ioloop_mt.__index = ioloop_mt

--- Initialize ioloop instance
-- @tparam table opts							ioloop creation options table
-- @tparam[opt=0.005] number opts.timeout		network operations timeout in seconds
-- @tparam[opt=0] number opts.sleep				sleep interval after each iteration
-- @tparam[opt] function opts.sleep_function	custom sleep function to call after each iteration
-- @treturn ioloop_mt ioloop instance
function ioloop_mt:__init(opts)
	log:debug("initializing ioloop instance '%s'", tostring(self))
	opts = opts or {}
	opts.timeout = opts.timeout or 0.005
	opts.sleep = opts.sleep or 0
	opts.sleep_function = opts.sleep_function or require("socket").sleep
	self.opts = opts
	self.clients = {}
	self.running = false --ioloop running flag, used by MQTT clients which are adding after this ioloop started to run
end

--- Add MQTT client or a loop function to the ioloop instance
-- @tparam client_mt|function client MQTT client or a loop function to add to ioloop
-- @return true on success or false and error message on failure
function ioloop_mt:add(client)
	local clients = self.clients
	if clients[client] then
		if type(client) == "table" then
			log:warn("MQTT client '%s' was already added to ioloop '%s'", client.opts.id, tostring(self))
			return false, "MQTT client was already added to this ioloop"
		else
			log:warn("MQTT loop function '%s' was already added to this ioloop '%s'", tostring(client), tostring(self))
			return false, "MQTT loop function was already added to this ioloop"
		end
	end
	clients[#clients + 1] = client
	clients[client] = true

	if type(client) == "table" then
		log:info("adding client '%s' to ioloop '%s'", client.opts.id, tostring(self))
		-- create and add function for PINGREQ
		local function f()
			if not clients[client] then
				-- the client were supposed to do keepalive for is gone, remove ourselves
				self:remove(f)
			end
			return client:check_keep_alive()
		end
		-- add it to start doing keepalive checks
		self:add(f)
	else
		log:info("adding function '%s' to ioloop '%s'", tostring(client), tostring(self))
	end

	return true
end

--- Remove MQTT client or a loop function from the ioloop instance
-- @tparam client_mt|function client MQTT client or a loop function to remove from ioloop
-- @return true on success or false and error message on failure
function ioloop_mt:remove(client)
	local clients = self.clients
	if not clients[client] then
		if type(client) == "table" then
			log:warn("MQTT client not found '%s' in ioloop '%s'", client.opts.id, tostring(self))
			return false, "MQTT client not found"
		else
			log:warn("MQTT loop function not found '%s' in ioloop '%s'", tostring(client), tostring(self))
			return false, "MQTT loop function not found"
		end
	end

	-- search an index of client to remove
	for i, item in ipairs(clients) do
		if item == client then
			-- found it, remove
			tbl_remove(clients, i)
			clients[client] = nil
			break
		end
	end

	if type(client) == "table" then
		log:info("removed client '%s' from ioloop '%s'", client.opts.id, tostring(self))
	else
		log:info("removed loop function '%s' from ioloop '%s'", tostring(client), tostring(self))
	end

	return true
end

--- Perform one ioloop iteration.
-- TODO: make this smarter do not wake-up functions or clients returned a longer
-- sleep delay. Currently it's pretty much a busy loop.
function ioloop_mt:iteration()
	local opts = self.opts
	local sleep = opts.sleep

	for _, client in ipairs(self.clients) do
		local t, err
		-- read data and handle events
		if type(client) ~= "function" then
			t, err = client:step()
			if t == -1 then
				--  no data read, client is idle
				t = nil
			elseif not t then
				if not client.opts.reconnect then
					-- error and not reconnecting, remove the client
					log:error("client '%s' failed with '%s', will not re-connect", client.opts.id, err)
					self:remove(client)
					t = nil
				else
					-- error, but will reconnect
					log:error("client '%s' failed with '%s', will try re-connecting", client.opts.id, err)
					t = 0 -- try immediately
				end
			end
		else
			t = client()
		end
		t = t or opts.sleep
		sleep = math_min(sleep, t)
	end
	-- sleep a bit
	if sleep > 0 then
		opts.sleep_function(sleep)
	end
end

--- Run ioloop while there is at least one client/function in the ioloop
function ioloop_mt:run_until_clients()
	log:info("ioloop started with %d clients/functions", #self.clients)

	self.running = true
	while next(self.clients) do
		self:iteration()
	end
	self.running = false

	log:info("ioloop finished with %d clients/functions", #self.clients)
end

-------

--- Create IO loop instance with given options
-- @see ioloop_mt:__init
-- @treturn ioloop_mt ioloop instance
local function ioloop_create(opts)
	local inst = setmetatable({}, ioloop_mt)
	inst:__init(opts)
	return inst
end
ioloop.create = ioloop_create

-- Default ioloop instance
local ioloop_instance

--- Returns default ioloop instance
-- @tparam[opt=true] boolean autocreate Automatically create ioloop instance
-- @tparam[opt] table opts Arguments for creating ioloop instance
-- @treturn ioloop_mt ioloop instance
function ioloop.get(autocreate, opts)
	if autocreate == nil then
		autocreate = true
	end
	if autocreate and not ioloop_instance then
		log:info("auto-creating default ioloop instance")
		ioloop_instance = ioloop_create(opts)
	end
	return ioloop_instance
end

-------

-- export module table
return ioloop

-- vim: ts=4 sts=4 sw=4 noet ft=lua
