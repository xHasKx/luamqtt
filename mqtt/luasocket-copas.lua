-- DOC: https://keplerproject.github.io/copas/
-- NOTE: you will need to install copas like this: luarocks install copas

-- module table
local connector = {}

local socket = require("socket")
local copas = require("copas")

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function connector.connect(conn)
	local sock, err = socket.connect(conn.host, conn.port)
	if not sock then
		return false, "socket.connect failed: "..err
	end
	conn.sock = sock
	return true
end

-- Shutdown network connection
function connector.shutdown(conn)
	conn.sock:shutdown()
end

-- Send data to network connection
function connector.send(conn, data, i, j)
	local ok, err = copas.send(conn.sock, data, i, j)
	return ok, err
end

-- Receive given amount of data from network connection
function connector.receive(conn, size)
	local ok, err = copas.receive(conn.sock, size)
	return ok, err
end

-- Set connection's socket to non-blocking mode and set a timeout for it
function connector.settimeout(conn, timeout)
	conn.timeout = timeout
	conn.sock:settimeout(0)
end

-- export module table
return connector

-- vim: ts=4 sts=4 sw=4 noet ft=lua
