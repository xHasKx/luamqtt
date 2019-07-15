-- load mqtt module
local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
	clean = true,
}
print("created MQTT client", client)

client:on{
	connect = function(connack)
		if connack.rc ~= 0 then
			print("connection to broker failed:", connack:reason_string(), connack)
			return
		end
		print("connected:", connack) -- successful connection

		-- subscribe to test topic and publish message after it
		assert(client:subscribe{ topic="luamqtt/#", qos=1, callback=function(suback)
			print("subscribed:", suback)

			-- publish test message
			print('publishing test message "hello" to "luamqtt/simpletest" topic...')
			assert(client:publish{
				topic = "luamqtt/simpletest",
				payload = "hello",
				qos = 1
			})
		end})
	end,

	message = function(msg)
		assert(client:acknowledge(msg))

		print("received:", msg)
		print("disconnecting...")
		assert(client:disconnect())
	end,

	error = function(err)
		print("MQTT client error:", err)
	end,

	close = function()
		print("MQTT conn closed")
	end
}

-- run io loop for client until connection close
-- please note that in sync mode background PINGREQ's are not available, and automatic reconnects too
print("running client in synchronous input/output loop")
mqtt.run_sync(client)

print("done, synchronous input/output loop is stopped")