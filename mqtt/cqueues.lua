-- DOC: http://w3.impa.br/~diego/software/luasocket/tcp.html

-- module table
local cq_socket = {}

local socket = require("cqueues.socket")

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function cq_socket.connect(conn)
	local sock, err = socket.connect(conn.host, conn.port)
	if not sock then
		return false, "cqueues.socket.connect failed: "..err
	end
	conn.sock = sock
	return true
end

-- Shutdown network connection
function cq_socket.shutdown(conn)
	conn.sock:shutdown()
end

-- Send data to network connection
function cq_socket.send(conn, data, i, j)
	if not j then
		j = #data
	end

	local ok, err = conn.sock:send(data, i, j)
	-- print("    luasocket.send:", ok, err, require("mqtt.tools").hex(data))
	return ok, err
end

-- Receive given amount of data from network connection
function cq_socket.receive(conn, size)
	return conn.sock:read(size)
end

-- Set connection's socket to non-blocking mode and set a timeout for it
function cq_socket.settimeout(conn, timeout)
	conn.timeout = timeout
	conn.sock:settimeout(timeout, "t")
end

-- export module table
return cq_socket

-- vim: ts=4 sts=4 sw=4 noet ft=lua
