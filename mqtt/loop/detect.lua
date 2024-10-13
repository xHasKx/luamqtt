--- Module returns a single function to detect the io-loop in use.
-- Either 'copas', 'nginx', or 'ioloop', or nil+error
local log = require "mqtt.log"

local loop
return function()
	if loop then return loop end
	if type(ngx) == "table" then
		-- there is a global 'ngx' table, so we're running OpenResty
		log:info("[LuaMQTT] auto-detected Nginx as the runtime environment")
		loop = "nginx"
		return loop

	elseif package.loaded.copas then
		-- 'copas' was already loaded
		log:info("[LuaMQTT] auto-detected Copas as the io-loop in use")
		loop = "copas"
		return loop

	elseif pcall(require, "socket") and tostring(require("socket")._VERSION):find("LuaSocket") then
		-- LuaSocket is available
		log:info("[LuaMQTT] auto-detected LuaSocket as the socket library to use with mqtt-ioloop")
		loop = "ioloop"
		return loop

	else
		-- unknown
		return nil, "LuaMQTT io-loop/connector auto-detection failed, please specify one explicitly"
	end
end
