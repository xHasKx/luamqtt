-- module table
-- thanks to @irimiab: https://github.com/xHasKx/luamqtt/issues/13
local super = require "mqtt.non_buffered_base"
local ngxsocket = setmetatable({}, super)
ngxsocket.__index = ngxsocket
ngxsocket.super = super

-- load required stuff
local ngx_socket_tcp = ngx.socket.tcp

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function ngxsocket:connect()
	local sock = ngx_socket_tcp()
	sock:settimeout(self.timeout * 1000) -- millisecs
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

-- Receive given amount of data from network connection
function ngxsocket:receive(size)
	local sock = self.sock
	local data, err = sock:receive(size)
	if data then
		return data
	end

	-- note: signal_idle is not needed here since OpenResty takes care
	-- of that. The read is non blocking, so a timeout is a real error and not
	-- a signal to retry.
	if err == "closed" then
		return false, self.signal_closed
	else
		return false, err
	end
end

-- export module table
return ngxsocket
