-- busted -e 'package.path="./?/init.lua;"..package.path;' spec/*.lua
-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

describe("MQTT lua library", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	it("has .client function", function()
		assert.are.equal("function", type(mqtt.client))
	end)
end)

describe("MQTT client", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	it("main test", function()
		local client_debug = nil -- print
		-- test servers
		local cases = {
			{
				name = "mqtt.flespi.io no SSL",
				id = "luamqtt-test-flespi",
				debug = client_debug,
				uri = "mqtt.flespi.io",
				clean = true,
				auth = {username = "tdFzK216XmzUA5sxLIOyJl62fDVQiI7CLC1juRff3C0syiP9PtwoCqeGUZm0xks7"},
			},
			{
				name = "test.mosquitto.org no SSL",
				id = "luamqtt-test-mosquitto",
				debug = client_debug,
				uri = "test.mosquitto.org",
				clean = true,
			},
			{
				name = "mqtt.flespi.io SSL",
				-- id = "luamqtt-test-flespi-ssl", -- testing randomly generated client id
				debug = client_debug,
				uri = "mqtt.flespi.io",
				ssl = true,
				clean = true,
				auth = {username = "tdFzK216XmzUA5sxLIOyJl62fDVQiI7CLC1juRff3C0syiP9PtwoCqeGUZm0xks7"},
			},
			{
				name = "test.mosquitto.org SSL",
				id = "luamqtt-test-mosquitto",
				debug = client_debug,
				uri = "test.mosquitto.org",
				ssl = true,
				clean = true,
			},
		}
		for _, case in ipairs(cases) do
			print("=====")
			print("=====", case.name)
			print("=====")

			-- create client
			local client = mqtt.client(case)

			-- set on-connect handler
			client:on("connect", function(connack)
				print("--- on connect", connack)

				client:subscribe{
					topic = "luamqtt/0/test",
				}

				client:publish{
					topic = "luamqtt/0/test",
					payload = "initial",
				}

				client:on("message", function(msg)
					print("--- on message", msg)
					client:acknowledge(msg)

					if msg.topic == "luamqtt/0/test" then
						-- re-subscribe test
						client:unsubscribe("luamqtt/0/test")
						client:subscribe{
							topic = "luamqtt/#",
							qos = 2,
						}

						client:publish{
							topic = "luamqtt/1/test",
							payload = "testing QoS 1",
							qos = 1,
						}
					elseif msg.topic == "luamqtt/1/test" then
						client:publish{
							topic = "luamqtt/2/test",
							payload = "testing QoS 2",
							qos = 2,
						}
					elseif msg.topic == "luamqtt/2/test" then
						-- done
						client:disconnect()
					end
				end)
			end)

			client:on("close", function()
				print("--- on close", client)
			end)

			-- set on-error handler
			client:on("error", function(err)
				print("--- on error", err)
			end)

			-- and wait for connection to broker is closed
			assert(client:connect_and_run())
		end
	end)

end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
