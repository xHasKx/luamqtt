--- Auto detect the connector to use.
-- The different environments require different socket implementations to work
-- properly. The 'connectors' are an abstraction to facilitate that without
-- having to modify the client itself.
--
-- This module is will auto-detect the environment and return the proper
-- module from;
--
-- * `mqtt.connector.nginx` for using the non-blocking OpenResty co-socket apis
--
-- * `mqtt.connector.copas` for the non-blocking Copas wrapped sockets
--
-- * `mqtt.connector.luasocket` for LuaSocket based sockets (blocking)
--
-- Since the selection is based on a.o. packages loaded, make sure that in case
-- of using the `copas` scheduler, you require it before the `mqtt` modules.
--
-- Since the `client` defaults to this module (`mqtt.connector`) there typically
-- is no need to use this directly. When implementing your own connectors,
-- the included connectors provide good examples of what to look out for.
-- @module mqtt.connector

local loops = setmetatable({
	copas = "mqtt.connector.copas",
	nginx = "mqtt.connector.nginx",
	ioloop = "mqtt.connector.luasocket"
}, {
	__index = function()
		error("failed to auto-detect connector to use, please set one explicitly", 2)
	end
})
local loop = require("mqtt.loop.detect")()

return require(loops[loop])
