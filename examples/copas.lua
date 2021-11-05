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


local function add_client(cl)
	-- add keep-alive timer
	local timer = copas.addthread(function()
		while cl do
			copas.sleep(cl:check_keep_alive())
		end
	end)
	-- add client to connect and listen
	copas.addthread(function()
		while cl do
			local timeout = cl:step()
			if not timeout then
				cl = nil -- exiting
				copas.wakeup(timer)
			else
				if timeout > 0 then
					copas.sleep(timeout)
				end
			end
		end
	end)
end


add_client(client)
copas.loop()
print("done, copas loop is stopped")
