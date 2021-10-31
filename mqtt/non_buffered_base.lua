-- base connector class for non-buffered reading.
--
-- Use this base class if the sockets DO yield.
-- So Copas or OpenResty for example, when using LuaSocket
-- use the buffered base class.
--
-- NOTE: when the send operation can also yield (as is the case with Copas and
-- OpenResty) you should wrap the `send` handler in a lock to prevent a half-send
-- message from being interleaved by another message send from another thread.
--
-- @class mqtt.non_buffered_base


local non_buffered = {
	type = "non-buffered, yielding i/o",
	timeout = 30 -- default timeout
}
non_buffered.__index = non_buffered

-- we need to specify signals for these conditions such that the client
-- doesn't have to rely on magic strings like "timeout", "wantread", etc.
-- the connector is responsible for translating those connector specific
-- messages to a generic signal
non_buffered.signal_idle = {} -- read timeout occured, so we're idle need to come back later and try again
non_buffered.signal_closed = {}	-- remote closed the connection

--- Clears consumed bytes.
-- Called by the mqtt client when the consumed bytes from the buffer are handled
-- and can be cleared from the buffer.
-- A no-op for the non-buffered classes, since the sockets yield when incomplete.
function non_buffered.buffer_clear()
end

--- Retrieves the requested number of bytes from the socket.
-- If the receive errors, because of a closed connection it should return
-- `nil, self.signal_closed` to indicate this. Any other errors can be returned
-- as a regular `nil, err`.
-- @tparam size int number of retrieve to return.
-- @return data, or `false, err`, where `err` can be a signal.
function non_buffered:receive(size) -- luacheck: ignore
    error("method 'receive' on non-buffered connector wasn't implemented")
end

--- Open network connection to `self.host` and `self.port`.
-- @return `true` on success, or `false, err` on failure
function non_buffered:connect() -- luacheck: ignore
    error("method 'connect' on connector wasn't implemented")
end

--- Shutdown the network connection.
function non_buffered:shutdown() -- luacheck: ignore
    error("method 'shutdown' on connector wasn't implemented")
end

--- Shutdown the network connection.
-- @tparam data string data to send
-- @return `true` on success, or `false, err` on failure
function non_buffered:send(data) -- luacheck: ignore
    error("method 'send' on connector wasn't implemented")
end

return non_buffered
