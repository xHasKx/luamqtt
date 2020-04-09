-- DOC: http://w3.impa.br/~diego/software/luasocket/tcp.html

-- module table
local luasocket_ssl = {}

local type = type
local assert = assert
local luasocket = require("mqtt.luasocket")

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function luasocket_ssl.connect(conn)
	assert(type(conn.secure_params) == "table", "expecting .secure_params to be a table")

	-- open usual TCP connection
	local ok, err = luasocket.connect(conn)
	if not ok then
		return false, "luasocket connect failed: "..err
	end
	local wrapped

	-- load right ssl module
	local ssl = require(conn.ssl_module or "ssl")

	-- TLS/SSL initialization
	wrapped, err = ssl.wrap(conn.sock, conn.secure_params)
	if not wrapped then
		conn.sock:shutdown()
		return false, "ssl.wrap() failed: "..err
	end
	ok = wrapped:dohandshake()
	if not ok then
		conn.sock:shutdown()
		return false, "ssl dohandshake failed"
	end

	-- replace sock in connection table with wrapped secure socket
	conn.sock = wrapped
	return true
end

-- Shutdown network connection
function luasocket_ssl.shutdown(conn)
	conn.sock:close()
end

-- Copy original methods from mqtt.luasocket module
luasocket_ssl.send = luasocket.send
luasocket_ssl.receive = luasocket.receive
luasocket_ssl.settimeout = luasocket.settimeout

-- export module table
return luasocket_ssl

-- vim: ts=4 sts=4 sw=4 noet ft=lua
