local _M = {}

local mqtt = require "mqtt"

function _M.add(client)
	local default_loop = mqtt.get_ioloop()
	return default_loop:add(client)
end

return setmetatable(_M, {
	__call = function(self, ...)
		return self.add(...)
	end,
})
