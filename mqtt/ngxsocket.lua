-- module table
-- thanks to @irimiab: https://github.com/xHasKx/luamqtt/issues/13
local ngxsocket = {}

-- load required stuff
local string_sub = string.sub
local ngx_socket_tcp = ngx.socket.tcp -- luacheck: ignore

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function ngxsocket.connect(conn)
	local socket = ngx_socket_tcp()
	socket:settimeout(0x7FFFFFFF)
	local sock, err = socket:connect(conn.host, conn.port)
	if not sock then
		return false, "socket:connect failed: "..err
	end
	if conn.secure then
		socket:sslhandshake()
	end
	conn.sock = socket
	return true
end

-- Shutdown network connection
function ngxsocket.shutdown(conn)
	conn.sock:close()
end

-- Send data to network connection
function ngxsocket.send(conn, data, i, j)
	if i then
		return conn.sock:send(string_sub(data, i, j))
	else
		return conn.sock:send(data)
	end
end

-- Receive given amount of data from network connection
function ngxsocket.receive(conn, size)
	return conn.sock:receive(size)
end

-- Set connection's socket to non-blocking mode and set a timeout for it
function ngxsocket.settimeout(conn, timeout)
	if not timeout then
		conn.sock:settimeout(0x7FFFFFFF)
	else
		conn.sock:settimeout(timeout * 1000)
	end
end

-- export module table
return ngxsocket
