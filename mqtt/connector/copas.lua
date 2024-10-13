--- Copas based connector.
--
-- Copas is an advanced coroutine scheduler in pure-Lua. It uses LuaSocket
-- under the hood, but in a non-blocking way. It also uses LuaSec for TLS
-- based connections (like the `mqtt.connector.luasocket` one). And hence uses
-- the same defaults for the `secure` option when creating the `client`.
--
-- Caveats:
--
-- * the `client` option `ssl_module` is not supported by the Copas connector,
--   It will always use the module named `ssl`.
--
-- * multiple threads can send simultaneously (sending is wrapped in a lock)
--
-- * since the client creates a long lived connection for reading, it returns
--   upon receiving a packet, to call an event handler. The handler must return
--   swiftly, since while the handler runs the socket will not be reading.
--   Any task that might take longer than a few milliseconds should be off
--   loaded to another thread (the Copas-loop will take care of this).
--
-- NOTE: you will need to install copas like this: `luarocks install copas`.
-- @module mqtt.connector.copas

local super = require "mqtt.connector.base.non_buffered_base"
local connector = setmetatable({}, super)
connector.__index = connector
connector.super = super

local socket = require("socket")
local copas = require("copas")
local new_lock = require("copas.lock").new
local validate_luasec = require("mqtt.connector.base.luasec")


-- validate connection options
function connector:validate()
	if self.secure then
		assert(self.ssl_module == "ssl" or self.ssl_module == nil, "Copas connector only supports 'ssl' as 'ssl_module'")

		validate_luasec(self)
	end
end

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function connector:connect()
	self:validate()
	local sock = copas.wrap(socket.tcp(), self.secure_params)
	copas.setsocketname("mqtt@"..self.host..":"..self.port, sock)

	sock:settimeouts(self.timeout, self.timeout, -1) -- no timout on reading

	local ok, err = sock:connect(self.host, self.port)
	if not ok then
		return false, "copas.connect failed: "..err
	end
	self.sock = sock
	self.send_lock = new_lock(30) -- 30 second timeout
	return true
end

-- the packet was fully read, we can clear the bufer.
function connector:buffer_clear()
	-- since the packet is complete, we wait now indefinitely for the next one
	self.sock:settimeouts(nil, nil, -1) -- no timeout on reading
end

-- Shutdown network connection
function connector:shutdown()
	self.sock:close()
	self.send_lock:destroy()
end

-- Send data to network connection
function connector:send(data)
	-- cache locally in case lock/sock gets replaced while we were sending
	local sock = self.sock
	local lock = self.send_lock

	local ok, err = lock:get()
	if not ok then
		return nil, "failed acquiring send_lock: "..tostring(err)
	end

	local i = 1
	while i < #data do
		i, err = sock:send(data, i)
		if not i then
			lock:release()
			return false, err
		end
	end
	lock:release()
	return true
end

-- Receive given amount of data from network connection
function connector:receive(size)
	local sock = self.sock
	local data, err = sock:receive(size)
	if data then
		-- bytes received, so change from idefinite timeout to regular until
		-- packet is complete (see buffer_clear method)
		self.sock:settimeouts(nil, nil, self.timeout)
		return data
	end

	if err == "closed" then
		return false, self.signal_closed
	elseif err == "timout" then
		return false, self.signal_idle
	else
		return false, err
	end
end

-- export module table
return connector

-- vim: ts=4 sts=4 sw=4 noet ft=lua
