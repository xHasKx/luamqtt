local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	id = "luamqtt-example-will-1",
	-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtts://mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
	clean = true,
	-- specifying last will message
	will = {
		topic = "luamqtt/lost",
		payload = "client-1 connection lost last will message",
	},

	-- event handlers
	on = {
		connect = function(connack, self)
			if connack.rc ~= 0 then
				print("connection to broker failed:", connack:reason_string(), connack)
				return
			end
			print("connected:", connack)

			-- subscribe to topic when we are expecting connection close command from client-2
			assert(self:subscribe{ topic="luamqtt/close", qos=1, callback=function()
				print("subscribed to luamqtt/close, waiting for connection close command from client-2")
			end})
		end,

		message = function(msg, self)
			assert(self:acknowledge(msg))

			print("received:", msg)
			print("closing connection without DISCONNECT and stopping client-1")
			self:close_connection() -- will message should be sent
		end,

		error = function(err)
			print("MQTT client error:", err)
		end,
	}
}

-- start receive loop
mqtt.run_ioloop(client)
