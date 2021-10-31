-- DOC: http://w3.impa.br/~diego/software/luasocket/tcp.html

-- module table
local super = require "mqtt.luasocket"
local luasocket_ssl = setmetatable({}, super)
luasocket_ssl.__index = luasocket_ssl
luasocket_ssl.super = super

local type = type
local assert = assert

-- table with error messages that indicate a read timeout
-- luasec has 2 extra timeout messages over luasocket
luasocket_ssl.timeout_errors = {
	wantread = true,
	wantwrite = true,
}
for k,v in pairs(super.timeout_errors) do luasocket_ssl.timeout_errors[k] = v end

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function luasocket_ssl:connect()
	assert(type(self.secure_params) == "table", "expecting .secure_params to be a table")

	-- open usual TCP connection
	local ok, err = super.connect(self)
	if not ok then
		return false, "luasocket connect failed: "..tostring(err)
	end

	-- load right ssl module
	local ssl = require(self.ssl_module or "ssl")

	-- Wrap socket in TLS one
	do
		local wrapped
		wrapped, err = ssl.wrap(self.sock, self.secure_params)
		if not wrapped then
			super.shutdown(self)
			return false, "ssl.wrap() failed: "..tostring(err)
		end

		-- replace sock in connection table with wrapped secure socket
		self.sock = wrapped
	end

	-- do TLS/SSL initialization/handshake
	self.sock:settimeout(self.timeout)
	ok, err = self.sock:dohandshake()
	if not ok then
		self:shutdown()
		return false, "ssl dohandshake failed: "..tostring(err)
	end

	return true
end

-- Shutdown network connection
function luasocket_ssl:shutdown()
	self.sock:close() -- why does ssl use 'close' where luasocket uses 'shutdown'??
end

-- export module table
return luasocket_ssl

-- vim: ts=4 sts=4 sw=4 noet ft=lua
