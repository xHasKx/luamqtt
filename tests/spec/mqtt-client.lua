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

	local client_debug = nil -- print
		-- test servers
		local cases = {
			{
				name = "mqtt.flespi.io no SSL",
				id = "luamqtt-test-flespi",
				debug = client_debug,
				uri = "mqtt.flespi.io",
				clean = true,
				auth = {username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"},
			},
			{
				name = "mqtt.flespi.io SSL",
				-- id = "luamqtt-test-flespi-ssl", -- testing randomly generated client id
				debug = client_debug,
				uri = "mqtt.flespi.io",
				ssl = true,
				clean = true,
				auth = {username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"},
			},
			{
				name = "test.mosquitto.org no SSL",
				id = "luamqtt-test-mosquitto",
				debug = client_debug,
				uri = "test.mosquitto.org", -- NOTE: this broker is not working sometimes
				clean = true,
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
		it("complex test - "..case.name, function()	

			-- create client
			local client = mqtt.client(case)

			-- set on-connect handler
			client:on("connect", function(connack)
				if client_debug then client_debug("--- on connect", case.name, connack) end

				client:subscribe{
					topic = "luamqtt/0/test",
				}

				client:publish{
					topic = "luamqtt/0/test",
					payload = "initial",
				}

				client:on("message", function(msg)
					if client_debug then client_debug("--- on message", case.name, msg) end
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
				if client_debug then client_debug("--- on close", case.name, client) end
			end)

			-- set on-error handler
			client:on("error", function(err)
				if client_debug then client_debug("--- on error", case.name, err) end
			end)

			-- and wait for connection to broker is closed
			assert(client:connect_and_run())
		end)
	end
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
