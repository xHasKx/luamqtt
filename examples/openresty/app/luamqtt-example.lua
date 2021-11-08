-- runs in init_worker_by_lua phase

-- IMPORTANT: set up logging before loading MQTT lib
if pcall(require, "logging.nginx") then
	-- LuaLogging nginx forwarder is available
	ngx.log(ngx.INFO, "forwarding LuaMQTT logs to nginx log, using LuaLogging 'nginx' logger")
	local ll = require("logging")
	ll.defaultLogger(ll.nginx()) -- forward logs to nginx logs
else
	ngx.log(ngx.WARN, "LuaLogging module 'logging.nginx' not found, it is strongly recommended to install that module. ",
		"See https://github.com/lunarmodules/lualogging.")
end


local mqtt = require "mqtt"
local add_client = require("mqtt.loop").add


-- create mqtt client
local client = mqtt.client{
	-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtts://mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
	clean = true,

	-- event handlers
	on = {
		connect = function(connack, self)
			if connack.rc ~= 0 then
				return
			end

			-- subscribe to test topic and publish message after it
			assert(self:subscribe{ topic="luamqtt/#", qos=1, callback=function()
				-- publish test message
				assert(self:publish{
					topic = "luamqtt/simpletest",
					payload = "hello",
					qos = 1
				})
			end})
		end,

		message = function(msg, self)
			assert(self:acknowledge(msg))

			ngx.log(ngx.INFO, "received:", msg)
		end,

		close = function(conn)
			ngx.log(ngx.INFO, "MQTT conn closed:", conn.close_reason)
		end
	}
}

-- start the client
add_client(client)
