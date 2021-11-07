-- module table
-- thanks to @irimiab: https://github.com/xHasKx/luamqtt/issues/13
local super = require "mqtt.connector.base.non_buffered_base"
local ngxsocket = setmetatable({}, super)
ngxsocket.__index = ngxsocket
ngxsocket.super = super

-- load required stuff
local ngx_socket_tcp = ngx.socket.tcp


-- validate connection options
function ngxsocket:validate()
	if self.secure then
		assert(self.ssl_module == "ssl", "specifying custom ssl module when using Nginx connector is not supported")
		assert(type(self.secure_params) == "table", "expecting .secure_params to be a table")
		-- TODO: validate nginx stuff
	end
end

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function ngxsocket:connect()
	local sock = ngx_socket_tcp()
	-- set read-timeout to 'nil' to not timeout at all
	assert(sock:settimeouts(self.timeout * 1000, self.timeout * 1000, nil)) -- millisecs
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
