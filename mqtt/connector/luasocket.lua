--- LuaSocket (and LuaSec) based connector.
--
-- This connector works with the blocking LuaSocket sockets. This connector uses
-- `LuaSec` for TLS connections. This is the connector used for the included
-- `mqtt.ioloop` scheduler.
--
-- When using TLS / MQTTS connections, the `secure` option passed to the `client`
-- when creating it, can be the standard table of options as used by LuaSec
-- for creating a context. When omitted the defaults will be;
-- `{ mode="client", protocol="any", verify="none",
--  options={ "all", "no_sslv2", "no_sslv3", "no_tlsv1" } }`
--
-- Caveats:
--
-- * since the client creates a long lived connection for reading, it returns
--   upon receiving a packet, to call an event handler. The handler must return
--   swiftly, since while the handler runs the socket will not be reading.
--   Any task that might take longer than a few milliseconds should be off
--   loaded to another task.
--
-- @module mqtt.connector.luasocket

local super = require "mqtt.connector.base.buffered_base"
local luasocket = setmetatable({}, super)
luasocket.__index = luasocket
luasocket.super = super

local socket = require("socket")
local validate_luasec = require("mqtt.connector.base.luasec")


-- table with error messages that indicate a read timeout
luasocket.timeout_errors = {
	timeout = true,   -- luasocket
	wantread = true,  -- luasec
	wantwrite = true, -- luasec
}

-- validate connection options
function luasocket:validate()
	if self.secure then
		validate_luasec(self)
	end
end

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function luasocket:connect()
	self:validate()

	local ssl
	if self.secure then
		ssl = require(self.ssl_module)
	end

	self:buffer_clear()  -- sanity
	local sock = socket.tcp()
	sock:settimeout(self.timeout)

	local ok, err = sock:connect(self.host, self.port)
	if not ok then
		return false, "socket.connect failed to connect to '"..tostring(self.host)..":"..tostring(self.port).."': "..err
	end

	if self.secure_params then
		-- Wrap socket in TLS one
		do
			local wrapped
			wrapped, err = ssl.wrap(sock, self.secure_params)
			if not wrapped then
				sock:close(self) -- close TCP level
				return false, "ssl.wrap() failed: "..tostring(err)
			end
			-- replace sock with wrapped secure socket
			sock = wrapped
		end

		-- do TLS/SSL initialization/handshake
		sock:settimeout(self.timeout) -- sanity; again since its now a luasec socket
		ok, err = sock:dohandshake()
		if not ok then
			sock:close()
			return false, "ssl dohandshake failed: "..tostring(err)
		end
	end

	self.sock = sock
	return true
end

-- Shutdown network connection
function luasocket:shutdown()
	self.sock:close()
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

	local data, err, partial = sock:receive(size)

	data = data or partial or ""
	if #data > 0 then
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
