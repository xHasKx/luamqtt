-- DOC: http://w3.impa.br/~diego/software/luasocket/tcp.html

-- module table
local super = require "mqtt.buffered_base"
local luasocket = setmetatable({}, super)
luasocket.__index = luasocket
luasocket.super = super

local socket = require("socket")

-- table with error messages that indicate a read timeout
luasocket.timeout_errors = {
	timeout = true,
}

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function luasocket:connect()
	self:buffer_clear()  -- sanity
	local sock = socket.tcp()
	sock:settimeout(self.timeout)

	local ok, err = sock:connect(self.host, self.port)
	if not ok then
		return false, "socket.connect failed to connect to '"..tostring(self.host)..":"..tostring(self.port).."': "..err
	end

	self.sock = sock
	return true
end

-- Shutdown network connection
function luasocket:shutdown()
	self.sock:shutdown()
end

-- Send data to network connection
function luasocket:send(data)
	local sock = self.sock
	local i = 0
	local err

	sock:settimeout(self.timeout)

	while i < #data do
		i, err = sock:send(data, i + 1)
		if not i then
			return false, err
		end
	end

	return true
end

-- Receive given amount of data from network connection
function luasocket:plain_receive(size)
	local sock = self.sock

	sock:settimeout(0)

	local data, err = sock:receive(size)
	if data then
		return data
	end

	-- convert error to signal if required
	if self.timeout_errors[err or -1] then
		return false, self.signal_idle
	elseif err == "closed" then
		return false, self.signal_closed
	else
		return false, err
	end
end


-- export module table
return luasocket

-- vim: ts=4 sts=4 sw=4 noet ft=lua
