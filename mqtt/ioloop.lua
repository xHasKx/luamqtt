--- This class contains the ioloop implementation.
--
-- In short: allowing you to work with several MQTT clients in one script, and allowing them to maintain
-- a long-term connection to broker, using PINGs. This is the bundled alternative to Copas and Nginx.
--
-- NOTE: this module will work only with MQTT clients using the `connector.luasocket` connector.
--
-- Providing an IO loop instance dealing with efficient (as much as possible in limited lua IO) network communication
-- for several MQTT clients in the same OS thread.
-- The main idea is that you are creating an ioloop instance, then adding MQTT clients to it.
-- Then ioloop is starting an endless loop trying to receive/send data for all added MQTT clients.
-- You may add more or remove some MQTT clients to/from the ioloop after it has been created and started.
--
-- Using an ioloop is allowing you to run a MQTT client for long time, through sending PINGREQ packets to broker
-- in keepAlive interval to maintain long-term connection.
--
-- Also, any function can be added to the ioloop instance, and it will be called in the same endless loop over and over
-- alongside with added MQTT clients to provide you a piece of processor time to run your own logic (like running your own
-- network communications or any other thing good working in an io-loop)
-- @classmod Ioloop

local _M = {}

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
local Ioloop = {}
Ioloop.__index = Ioloop

--- Initialize ioloop instance.
-- @tparam table opts							ioloop creation options table
-- @tparam[opt=0] number opts.sleep_min			min sleep interval after each iteration
-- @tparam[opt=0.002] number opts.sleep_step	increase in sleep after every idle iteration
-- @tparam[opt=0.030] number opts.sleep_max		max sleep interval after each iteration
-- @tparam[opt=luasocket.sleep] function opts.sleep_function	custom sleep function to call after each iteration
-- @treturn Ioloop ioloop instance
function Ioloop:__init(opts)
	log:debug("[LuaMQTT] initializing ioloop instance '%s'", tostring(self))
	opts = opts or {}
	opts.sleep_min = opts.sleep_min or 0
	opts.sleep_step = opts.sleep_step or 0.002
	opts.sleep_max = opts.sleep_max or 0.030
	opts.sleep_function = opts.sleep_function or require("socket").sleep
	self.opts = opts
	self.clients = {}
	self.timeouts = setmetatable({}, { __mode = "v" })
	self.running = false --ioloop running flag, used by MQTT clients which are adding after this ioloop started to run
end

--- Add MQTT client or a loop function to the ioloop instance.
-- When adding a function, the function should on each call return the time (in seconds) it wishes to sleep. The ioloop
-- will sleep after each iteration based on what clients/functions returned. So the function may be called sooner than
-- the requested time, but will not be called later.
-- @tparam client_mt|function client MQTT client or a loop function to add to ioloop
-- @return true on success or false and error message on failure
-- @usage
-- -- create a timer on a 1 second interval
-- local timer do
-- 	local interval = 1
-- 	local next_call = socket.gettime() + interval
-- 	timer = function()
-- 		if next_call >= socket.gettime() then
--
-- 			-- do stuff here
--
-- 			next_call = socket.gettime() + interval
-- 			return interval
-- 		else
-- 			return next_call - socket.gettime()
-- 		end
-- 	end
-- end
--
-- loop:add(timer)
function Ioloop:add(client)
	local clients = self.clients
	if clients[client] then
		if type(client) == "table" then
			log:warn("[LuaMQTT] client '%s' was already added to ioloop '%s'", client.opts.id, tostring(self))
			return false, "MQTT client was already added to this ioloop"
		else
			log:warn("[LuaMQTT] loop function '%s' was already added to this ioloop '%s'", tostring(client), tostring(self))
			return false, "MQTT loop function was already added to this ioloop"
		end
	end
	clients[#clients + 1] = client
	clients[client] = true
	self.timeouts[client] = self.opts.sleep_min

	if type(client) == "table" then
		log:info("[LuaMQTT] adding client '%s' to ioloop '%s'", client.opts.id, tostring(self))
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
		log:info("[LuaMQTT] adding function '%s' to ioloop '%s'", tostring(client), tostring(self))
	end

	return true
end

--- Remove MQTT client or a loop function from the ioloop instance
-- @tparam client_mt|function client MQTT client or a loop function to remove from ioloop
-- @return true on success or false and error message on failure
function Ioloop:remove(client)
	local clients = self.clients
	if not clients[client] then
		if type(client) == "table" then
			log:warn("[LuaMQTT] client not found '%s' in ioloop '%s'", client.opts.id, tostring(self))
			return false, "MQTT client not found"
		else
			log:warn("[LuaMQTT] loop function not found '%s' in ioloop '%s'", tostring(client), tostring(self))
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
		log:info("[LuaMQTT] removed client '%s' from ioloop '%s'", client.opts.id, tostring(self))
	else
		log:info("[LuaMQTT] removed loop function '%s' from ioloop '%s'", tostring(client), tostring(self))
	end

	return true
end

--- Perform one ioloop iteration.
-- TODO: make this smarter do not wake-up functions or clients returning a longer
-- sleep delay. Currently they will be tried earlier if another returns a smaller delay.
function Ioloop:iteration()
	local opts = self.opts
	local sleep = opts.sleep_max

	for _, client in ipairs(self.clients) do
		local t, err
		-- read data and handle events
		if type(client) ~= "function" then
			t, err = client:step()
		else
			t = client() or opts.sleep_max
		end
		if t == -1 then
			--  no data read, client is idle, step up timeout
			t = math_min(self.timeouts[client] + opts.sleep_step, opts.sleep_max)
			self.timeouts[client] = t
		elseif not t then
			-- an error from a client was returned
			if not client.opts.reconnect then
				-- error and not reconnecting, remove the client
				log:info("[LuaMQTT] client '%s' returned '%s', no re-connect set, removing client", client.opts.id, err)
				self:remove(client)
				t = opts.sleep_max
			else
				-- error, but will reconnect
				log:error("[LuaMQTT] client '%s' failed with '%s', will try re-connecting", client.opts.id, err)
				t = opts.sleep_min -- try asap
			end
		else
			-- a number of seconds was returned
			t = math_min(t, opts.sleep_max)
			self.timeouts[client] = opts.sleep_min
		end
		sleep = math_min(sleep, t)
	end
	-- sleep a bit
	if sleep > 0 then
		opts.sleep_function(sleep)
	end
end

--- Run the ioloop.
-- While there is at least one client/function in the ioloop it will continue
-- iterating. After all clients/functions are gone, it will return.
function Ioloop:run_until_clients()
	log:info("[LuaMQTT] ioloop started with %d clients/functions", #self.clients)

	self.running = true
	while next(self.clients) do
		self:iteration()
	end
	self.running = false

	log:info("[LuaMQTT] ioloop finished with %d clients/functions", #self.clients)
end

--- Exported functions
-- @section exported


--- Create IO loop instance with given options
-- @name ioloop.create
-- @see Ioloop:__init
-- @treturn Ioloop ioloop instance
function _M.create(opts)
	local inst = setmetatable({}, Ioloop)
	inst:__init(opts)
	return inst
end

-- Default ioloop instance
local ioloop_instance

--- Returns default ioloop instance
-- @name ioloop.get
-- @tparam[opt=true] boolean autocreate Automatically create ioloop instance
-- @tparam[opt] table opts Arguments for creating ioloop instance
-- @treturn Ioloop ioloop instance
function _M.get(autocreate, opts)
	if autocreate == nil then
		autocreate = true
	end
	if autocreate and not ioloop_instance then
		log:info("[LuaMQTT] auto-creating default ioloop instance")
		ioloop_instance = _M.create(opts)
	end
	return ioloop_instance
end

-------

-- export module table
return _M

-- vim: ts=4 sts=4 sw=4 noet ft=lua
