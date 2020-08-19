-- DOC: http://w3.impa.br/~diego/software/luasocket/tcp.html

-- module table
local luasocket = {}

local socket = require("socket")
local copas = require("copas")

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function luasocket.connect(conn)
	local sock, err = socket.connect(conn.host, conn.port)
	if not sock then
		return false, "socket.connect failed: "..err
	end
	conn.sock = sock
	return true
end

-- Shutdown network connection
function luasocket.shutdown(conn)
	conn.sock:shutdown()
end

-- Send data to network connection
function luasocket.send(conn, data, i, j)
	local ok, err = copas.send(conn.sock, data, i, j)
	return ok, err
end

-- Receive given amount of data from network connection
function luasocket.receive(conn, size)
	local ok, err = copas.receive(conn.sock, size)
	return ok, err
end

-- Set connection's socket to non-blocking mode and set a timeout for it
function luasocket.settimeout(conn, timeout)
	conn.timeout = timeout
	conn.sock:settimeout(0)
end

-- export module table
return luasocket

-- vim: ts=4 sts=4 sw=4 noet ft=lua
