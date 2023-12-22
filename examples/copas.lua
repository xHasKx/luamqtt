-- load mqtt module
local mqtt = require("mqtt")
local copas = require("copas")
local add_client = require("mqtt.loop").add

-- create mqtt client
local client = mqtt.client{
	-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtt://mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
	clean = true,

	-- create event handlers
	on = {
		connect = function(connack, self)
			if connack.rc ~= 0 then
				print("connection to broker failed:", connack:reason_string(), connack)
				return
			end
			print("connected:", connack) -- successful connection

			-- subscribe to test topic and publish message after it
			assert(self:subscribe{ topic="luamqtt/#", qos=1, callback=function(suback)
				print("subscribed:", suback)

				-- publish test message
				print('publishing test message "hello" to "luamqtt/simpletest" topic...')
				assert(self:publish{
					topic = "luamqtt/simpletest",
					payload = "hello",
					qos = 1
				})
			end})
		end,

		message = function(msg, self)
			assert(self:acknowledge(msg))

			print("received:", msg)
			print("disconnecting...")
			assert(self:disconnect())
		end,

		error = function(err)
			print("MQTT client error:", err)
		end,

		close = function()
			print("MQTT conn closed")
		end
	}, -- close 'on', event handlers
}

print("created MQTT client", client)

add_client(client)
copas.loop()

print("done, copas loop is stopped")
