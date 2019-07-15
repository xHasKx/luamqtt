local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	id = "luamqtt-example-will-2",
	-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
	clean = true,
	secure = true,
}

client:on{
	connect = function(connack)
		if connack.rc ~= 0 then
			print("connection to broker failed:", connack:reason_string(), connack)
			return
		end
		print("connected:", connack)

		-- subscribe to topic when we are expecting last-will message from client-1
		assert(client:subscribe{ topic="luamqtt/lost", qos=1, callback=function()
			print("subscribed to luamqtt/lost")

			-- publish close command to client-1
			assert(client:publish{
				topic = "luamqtt/close",
				payload = "Dear client-1, please close your connection",
				qos = 1,
			})
			print("published close command")
		end})
	end,

	message = function(msg)
		assert(client:acknowledge(msg))

		print("received:", msg)
		print("disconnecting and stopping client-2")
		client:disconnect()
	end,

	error = function(err)
		print("MQTT client error:", err)
	end,
}

-- start receive loop
mqtt.run_ioloop(client)
