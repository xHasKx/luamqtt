--- IOloop specific client handling module.
-- Typically this module is not used directly, but through `mqtt.loop` when
-- auto-detecting the environment.
-- @module mqtt.loop.ioloop

local _M = {}

local mqtt = require "mqtt"

--- Add MQTT client to the integrated ioloop.
-- The client will automatically be removed after it exits.  It will set up a
-- function to call `Client:check_keep_alive` in the ioloop.
-- @param client mqtt-client to add to the ioloop
-- @return `true` on success or `false` and error message on failure
function _M.add(client)
	local default_loop = mqtt.get_ioloop()
	return default_loop:add(client)
end

return setmetatable(_M, {
	__call = function(self, ...)
		return self.add(...)
	end,
})
