local log = require("logging").defaultLogger()

describe("copas connector", function()
	local mqtt = require("mqtt")
	local copas = require("copas")
	local prefix = "luamqtt/" .. tostring(math.floor(math.random()*1e13))

	it("test", function()
		-- NOTE: more about flespi tokens:
		-- https://flespi.com/kb/tokens-access-keys-to-flespi-platform
		local flespi_token = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"

		local client = mqtt.client{
			uri = "mqtt.flespi.io",
			clean = true,
			username = flespi_token,
			version = mqtt.v50,

			-- connector = require("mqtt.connector.copas"),  -- will be auto-detected
		}

		local test_finished = false

		client:on{
			connect = function()
				log:warn("client is now connected")
				log:warn("client subscribing to topic '.../copas'")
				assert(client:subscribe{topic=prefix.."/copas", qos=1, callback=function()
					log:warn("client subscription to topic '.../copas' confirmed")
					log:warn("client publishing 'copas test' to topic '.../copas' confirmed")
					assert(client:publish{
						topic = prefix.."/copas",
						payload = "copas test",
						qos = 1,
					})
				end})
			end,

			message = function(msg)
				assert(client:acknowledge(msg))
				if msg.topic == prefix.."/copas" and msg.payload == "copas test" then
					log:warn("client received '%s' to topic '.../copas' confirmed", msg.payload)
					assert(client:disconnect())
					log:warn("disconnected now")
					test_finished = true
				end
			end
		}

		copas.addthread(function()
			while true do
				local timeout = client:step()
				if not timeout then
					-- exited
					return
				end
				if timeout > 0 then
					copas.sleep(timeout)
				end
			end
		end)

		copas.loop()

		assert.is_true(test_finished, "expecting mqtt client to finish its work")
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
