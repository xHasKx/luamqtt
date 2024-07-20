-- base connector class for buffered reading.
--
-- Use this base class if the sockets do NOT yield.
-- So LuaSocket for example, when using Copas or OpenResty
-- use the non-buffered base class.
--
-- This base class derives from `non_buffered_base` it implements the
-- `receive` and `buffer_clear` methods. But adds the `plain_receive` method
-- that must be implemented.
--
-- NOTE: the `plain_receive` method is supposed to be non-blocking (see its
-- description), but the `send` method has no such facilities, so is `blocking`
-- in this class. Make sure to set the proper timeouts in either method before
-- starting the send/receive. So for example for LuaSocket call `settimeout(0)`
-- before receiving, and `settimeout(30)` before sending.
--
-- @class mqtt.connector.base.buffered_base


local super = require "mqtt.connector.base.non_buffered_base"
local buffered = setmetatable({}, super)
buffered.__index = buffered
buffered.super = super
buffered.type = "buffered, blocking i/o"

-- debug helper function
-- function buffered:buffer_state(msg)
-- 	print(string.format("buffer: size = %03d  last-byte-done = %03d -- %s",
-- 			#(self.buffer_string or ""), self.buffer_pointer or 0, msg))
-- end

-- bytes read were handled, clear those
function buffered:buffer_clear()
	-- self:buffer_state("before clearing buffer")
	self.buffer_string = nil
	self.buffer_pointer = nil
end

-- read bytes, first from buffer, remaining from function
-- if function returns "idle" then reset read pointer
function buffered:receive(size)
	-- self:buffer_state("receive start "..size.." bytes")

	local buf = self.buffer_string or ""
	local idx = self.buffer_pointer or 0

	while size > (#buf - idx) do
		-- buffer is lacking bytes, read more...
		local data, err = self:plain_receive(size - (#buf - idx))
		if not data then
			if err == self.signal_idle then
				-- read timedout, retry entire packet later, reset buffer
				self.buffer_pointer = 0
			end
			return data, err
		end

		-- append received data, and try again
		buf = buf .. data
		self.buffer_string = buf
		-- self:buffer_state("receive added "..#data.." bytes")
	end

	self.buffer_pointer = idx + size
	local data = buf:sub(idx + 1, idx + size)
	-- print("data: ", require("mqtt.tools").hex(data))
	-- self:buffer_state("receive done "..size.." bytes\n")
	return data
end

--- Retrieves the requested number of bytes from the socket, in a non-blocking
-- manner.
-- The implementation MUST read with a timeout that immediately returns if there
-- is no data to read. If there is no data, then it MUST return
-- `nil, self.signal_idle` to indicate it no data was there and we need to retry later.
--
-- If the receive errors, because of a closed connection it should return
-- `nil, self.signal_closed` to indicate this. Any other errors can be returned
-- as a regular `nil, err`.
-- @tparam size int number of bytes to receive.
-- @return data, or `false, err`, where `err` can be a signal.
function buffered:plain_receive(size) -- luacheck: ignore
    error("method 'plain_receive' on buffered connector wasn't implemented")
end

return buffered
