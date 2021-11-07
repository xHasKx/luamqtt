-- DOC: https://keplerproject.github.io/copas/
-- NOTE: you will need to install copas like this: luarocks install copas

-- module table
local super = require "mqtt.connector.base.non_buffered_base"
local connector = setmetatable({}, super)
connector.__index = connector
connector.super = super

local socket = require("socket")
local copas = require("copas")
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
	sock:settimeout(self.timeout)

	local ok, err = sock:connect(self.host, self.port)
	if not ok then
		return false, "copas.connect failed: "..err
	end
	self.sock = sock
	return true
end

-- Shutdown network connection
function connector:shutdown()
	self.sock:close()
end

-- Send data to network connection
function connector:send(data)
	local i = 1
	local err
	while i < #data do
		i, err = self.sock:send(data, i)
		if not i then
			return false, err
		end
	end
	return true
end

-- Receive given amount of data from network connection
function connector:receive(size)
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
return connector

-- vim: ts=4 sts=4 sw=4 noet ft=lua
