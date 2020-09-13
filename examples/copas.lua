-- load mqtt module
local mqtt = require("mqtt")
local copas = require("copas")

-- create mqtt client
local client = mqtt.client{
	-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
	clean = true,

	-- NOTE: copas connector
	connector = require("mqtt.luasocket-copas"),
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
copas.addthread(function()
	print("running client in separated copas thread #1...")
	mqtt.run_sync(client)

	-- NOTE: in sync mode no automatic reconnect is working, but you may just wrap "mqtt.run_sync(client)" call in a loop like this:
	-- while true do
	-- 	mqtt.run_sync(client)
	-- end
end)

copas.addthread(function()
	print("execution of separated copas thread #2...")
	copas.sleep(0.1)
	print("thread #2 stopped")
end)

copas.loop()
print("done, copas loop is stopped")
