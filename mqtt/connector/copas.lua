-- DOC: https://keplerproject.github.io/copas/
-- NOTE: you will need to install copas like this: luarocks install copas

-- module table
local super = require "mqtt.connector.base.non_buffered_base"
local connector = setmetatable({}, super)
connector.__index = connector
connector.super = super

local socket = require("socket")
local copas = require("copas")

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function connector:connect()
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
	self.sock:shutdown()
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

	-- note: signal_idle is not needed here since Copas takes care
	-- of that. The read is non blocking, so a timeout is a real error and not
	-- a signal to retry.
	if err == "closed" then
		return false, self.signal_closed
	else
		return false, err
	end
end

-- export module table
return connector

-- vim: ts=4 sts=4 sw=4 noet ft=lua
