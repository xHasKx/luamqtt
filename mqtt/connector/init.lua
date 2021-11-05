--- auto detect the connector to use.
-- This is based on a.o. libraries already loaded, so 'require' this
-- module as late as possible (after the other modules)
local log = require "mqtt.log"

if type(ngx) == "table" then
	-- there is a global 'ngx' table, so we're running OpenResty
	log:info("LuaMQTT auto-detected Nginx as the runtime environment")
	return require("mqtt.connector.nginx")

elseif package.loaded.copas then
	-- 'copas' was already loaded
	log:info("LuaMQTT auto-detected Copas as the io-loop in use")
	return require("mqtt.connector.copas")

elseif pcall(require, "socket") and tostring(require("socket")._VERSION):find("LuaSocket") then
	-- LuaSocket is available
	log:info("LuaMQTT auto-detected LuaSocket as the socket library to use")
	return require("mqtt.connector.luasocket")
end

error("connector auto-detection failed, please specify one explicitly")
