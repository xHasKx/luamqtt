--- Nginx OpenResty co-sockets based connector.
--
-- This connector works with the non-blocking openresty sockets. Note that the
-- secure setting haven't been implemented yet. It will simply use defaults
-- when doing a TLS handshake.
--
-- Caveats:
--
-- * sockets cannot cross phase/context boundaries. So all client interaction
--   must be done from the timer context in which the client threads run.
--
-- * multiple threads cannot send simultaneously (simple scenarios will just
--   work)
--
-- * since the client creates a long lived connection for reading, it returns
--   upon receiving a packet, to call an event handler. The handler must return
--   swiftly, since while the handler runs the socket will not be reading.
--   Any task that might take longer than a few milliseconds should be off
--   loaded to another thread.
--
-- * Nginx timers should be short lived because memory is only released after
--   the context is destroyed. In this case we're using the fro prolonged periods
--   of time, so be aware of this and implement client restarts if required.
--
-- thanks to @irimiab: https://github.com/xHasKx/luamqtt/issues/13
-- @module mqtt.connector.nginx

local super = require "mqtt.connector.base.non_buffered_base"
local ngxsocket = setmetatable({}, super)
ngxsocket.__index = ngxsocket
ngxsocket.super = super

-- load required stuff
local ngx_socket_tcp = ngx.socket.tcp
local long_timeout = 7*24*60*60*1000 -- one week

-- validate connection options
function ngxsocket:validate()
	if self.secure then
		assert(self.ssl_module == "ssl", "specifying custom ssl module when using Nginx connector is not supported")
		assert(self.secure_params == nil or type(self.secure_params) == "table", "expecting .secure_params to be a table if given")
		-- TODO: validate nginx stuff
	end
end

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function ngxsocket:connect()
	local sock = ngx_socket_tcp()
	-- set read-timeout to 'nil' to not timeout at all
	sock:settimeouts(self.timeout * 1000, self.timeout * 1000, long_timeout) -- no timeout on reading
	local ok, err = sock:connect(self.host, self.port)
	if not ok then
		return false, "socket:connect failed: "..err
	end
	if self.secure then
		sock:sslhandshake()
	end
	self.sock = sock
	return true
end

-- Shutdown network connection
function ngxsocket:shutdown()
	self.sock:close()
end

-- Send data to network connection
function ngxsocket:send(data)
	return self.sock:send(data)
end

function ngxsocket:buffer_clear()
	-- since the packet is complete, we wait now indefinitely for the next one
	self.sock:settimeouts(self.timeout * 1000, self.timeout * 1000, long_timeout) -- no timeout on reading
end

-- Receive given amount of data from network connection
function ngxsocket:receive(size)
	local sock = self.sock
	local data, err = sock:receive(size)
	if data then
		-- bytes received, so change from idefinite timeout to regular until
		-- packet is complete (see buffer_clear method)
		self.sock:settimeouts(self.timeout * 1000, self.timeout * 1000, self.timeout * 1000)
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
return ngxsocket
