--- auto detect the connector to use.
-- This is based on a.o. libraries already loaded, so 'require' this
-- module as late as possible (after the other modules)
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
