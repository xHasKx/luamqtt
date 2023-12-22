--- Auto detect the IO loop to use.
-- Interacting with the supported IO loops (ioloop, copas, and nginx) requires
-- specific implementations to get it right.
-- This module will auto-detect the environment and return the proper
-- module from;
--
-- * `mqtt.loop.ioloop`
--
-- * `mqtt.loop.copas`
--
-- * `mqtt.loop.nginx`
--
-- Since the selection is based on a.o. packages loaded, make sure that in case
-- of using the `copas` scheduler, you require it before the `mqtt` modules.
--
-- @usage
-- --local copas = require "copas"   -- only if you use Copas
-- local mqtt = require "mqtt"
-- local add_client = require("mqtt.loop").add  -- returns a loop-specific function
--
-- local client = mqtt.create { ... options ... }
-- add_client(client)  -- works for ioloop, copas, and nginx
--
-- @module mqtt.loop

local loops = setmetatable({
	copas = "mqtt.loop.copas",
	nginx = "mqtt.loop.nginx",
	ioloop = "mqtt.loop.ioloop"
}, {
	__index = function()
		error("failed to auto-detect connector to use, please set one explicitly", 2)
	end
})
local loop = require("mqtt.loop.detect")()

return require(loops[loop])
