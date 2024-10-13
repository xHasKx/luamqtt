-- DOC v3.1.1: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html
-- DOC v5.0: http://docs.oasis-open.org/mqtt/mqtt/v5.0/cos01/mqtt-v5.0-cos01.html

describe("ioloop", function()

	-- load MQTT lua library
	local mqtt = require("mqtt")

	-- common topics prefix with random part
	local prefix = "luamqtt/"..tostring(math.floor(math.random()*1e13))

	it("with additional loop function", function()
		-- create a MQTT client
		local client = mqtt.client{
			uri = "mqtt.flespi.io",
			clean = true,
			-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
			username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
		}

		local signal -- received message, signal to the ioloop function

		-- configure MQTT client handlers
		client:on{
			error = function(err)
				print("[error] ", err)
			end,
			connect = function()
				--print "connected"
				-- subscribe, then send signal message
				assert(client:subscribe{topic=prefix.."/ioloop/signal", callback=function()
					--print "subscribed"
					assert(client:publish{
						topic = prefix.."/ioloop/signal",
						payload = "signal",
					})
				end})
			end,
			message = function(msg)
				-- assign received message
				if msg.topic == prefix.."/ioloop/signal" then
					signal = msg
				end
			end,
		}

		-- custom ioloop function, will be called after each iteration of the created MQTT client
		local function loop_func()
			if signal then
				-- disconnect MQTT client, thus it will be removed from ioloop
				client:disconnect()
				mqtt.get_ioloop():remove(client)

				-- and remove this function from ioloop to stop it (no more clients left)
				mqtt.get_ioloop():remove(loop_func)
			end
		end

		-- run ioloop with additional loop function which will be called alongside with the MQTT client iterations
		mqtt.run_ioloop(client, loop_func)

		assert.truthy(signal)
	end)
end)
