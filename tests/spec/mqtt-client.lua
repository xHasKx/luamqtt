-- busted -e 'package.path="./?/init.lua;"..package.path;' spec/*.lua
-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html
-- DOC v5.0: http://docs.oasis-open.org/mqtt/mqtt/v5.0/cos01/mqtt-v5.0-cos01.html

describe("MQTT lua library", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	it("has .client function", function()
		assert.are.equal("function", type(mqtt.client))
	end)
end)

describe("invalid arguments to mqtt.client constructor", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	it("argument table key is not a string", function()
		assert.has_error(function() mqtt.client{1} end, "expecting string key in args, got: number")
	end)

	it("id is not a string", function()
		assert.has_error(function() mqtt.client{id=1} end, "expecting id to be a string")
	end)

	it("username is not a string", function()
		assert.has_error(function() mqtt.client{username=1} end, "expecting username to be a string")
	end)

	it("password is not a string", function()
		assert.has_error(function() mqtt.client{password=1} end, "expecting password to be a string")
	end)

	it("keep_alive is not a number", function()
		assert.has_error(function() mqtt.client{keep_alive=""} end, "expecting keep_alive to be a number")
	end)

	it("properties is not a table", function()
		assert.has_error(function() mqtt.client{properties=""} end, "expecting properties to be a table")
	end)

	it("user_properties is not a table", function()
		assert.has_error(function() mqtt.client{user_properties=""} end, "expecting user_properties to be a table")
	end)

	it("reconnect is not a number", function()
		assert.has_error(function() mqtt.client{reconnect=""} end, "expecting reconnect to be a boolean or number")
	end)

	it("unexpected key", function()
		assert.has_error(function() mqtt.client{unexpected=true} end, "unexpected key in client args: unexpected = true")
	end)

end)

describe("correct arguments to mqtt.client constructor", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	it("all available arguments", function()
		mqtt.client{
			uri = "test-broker.com",
			clean = true,
			version = mqtt.v50,
			id = "luamqtt-test",
			username = "admin",
			password = "admin",
			secure = true,
			will = { topic="luamqtt/will", payload="will payload", qos=1, retain = true, },
			keep_alive = 15,
			properties = {
				will_delay_interval = 20,
				payload_format_indicator = 1,
				message_expiry_interval = 86400,
			},
			user_properties = {a="b", c="d"},
			reconnect = 5,
			connector = require("mqtt.luasocket"),
			ssl_module = "ssl",
		}
	end)
end)

describe("MQTT client", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	-- test servers
	local cases = {
		{
			name = "mqtt.flespi.io PLAIN, MQTTv3.1.1",
			args = {
				-- id = "luamqtt-test-flespi", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.flespi.io",
				clean = true,
				-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
				username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
			}
		},
		{
			name = "mqtt.flespi.io PLAIN+sync, MQTTv3.1.1",
			sync = true,
			args = {
				-- id = "luamqtt-test-flespi", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.flespi.io",
				clean = true,
				-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
				username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
			}
		},
		{
			name = "mqtt.flespi.io SECURE, MQTTv3.1.1",
			args = {
				-- id = "luamqtt-test-flespi-ssl", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.flespi.io",
				secure = true,
				clean = true,
				-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
				username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
			}
		},
		{
			name = "mqtt.flespi.io PLAIN, MQTTv5.0",
			args = {
				-- id = "luamqtt-test-flespi", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.flespi.io",
				clean = true,
				version = mqtt.v50,
				-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
				username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
			}
		},
		{
			name = "mqtt.flespi.io SECURE, MQTTv5.0",
			args = {
				-- id = "luamqtt-test-flespi-ssl", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.flespi.io",
				version = mqtt.v50,
				clean = true,
				secure = true,
				-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
				username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
			}
		},
		--[[ -- NOTE: test.mosquitto.org is not working sometimes
		{
			name = "test.mosquitto.org PLAIN",
			args = {
				id = "luamqtt-test-mosquitto",
				uri = "test.mosquitto.org",
				clean = true,
			}
		},
		{
			name = "test.mosquitto.org SECURE",
			args = {
				-- id = "luamqtt-test-mosquitto", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "test.mosquitto.org",
				secure = true,
				clean = true,
			}
		},
		]]
		{
			name = "broker.hivemq.com PLAIN", -- NOTE: there is only plain (non-ssl) endpoint available on this broker
			args = {
				-- id = "luamqtt-test-mosquitto", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "broker.hivemq.com",
				clean = true,
			}
		},
		{
			name = "mqtt.fluux.io PLAIN, MQTTv3.1.1",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				clean = true,
			}
		},
		{
			name = "mqtt.fluux.io SECURE, MQTTv3.1.1",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				secure = true,
				clean = true,
			}
		},
		{
			name = "mqtt.fluux.io PLAIN, MQTTv5.0",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				clean = true,
				version = mqtt.v50,
			}
		},
		{
			name = "mqtt.fluux.io SECURE, MQTTv5.0",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				secure = true,
				clean = true,
				version = mqtt.v50,
			}
		},
	}

	local properties = {
		message_expiry_interval = 3600,
	}
	local user_properties = {
		hello = "MQTT v5.0!",
	}

	for _, case in ipairs(cases) do
		it("complex test - "..case.name, function()
			local errors = {}
			local acknowledge = false
			local test_msg_2 = false
			local close_reason

			-- create client
			local client = mqtt.client(case.args)

			-- common topics prefix with random part
			local prefix = "luamqtt/"..tostring(math.floor(math.random()*1e13))

			-- set on-connect handler
			client:on("connect", function()
				assert(client:send_pingreq()) -- NOTE: not required, it's here only to improve code coverage
				assert(client:subscribe{topic=prefix.."/0/test", callback=function()
					assert(client:publish{
						topic = prefix.."/0/test",
						payload = "initial",
					})
				end})
			end)

			client:on{
				message = function(msg)
					client:acknowledge(msg)

					if msg.topic == prefix.."/0/test" then
						-- re-subscribe test
						assert(client:unsubscribe{topic=prefix.."/0/test", callback=function()
							assert(client:subscribe{topic=prefix.."/#", qos=2, callback=function()
								assert(client:publish{
									topic = prefix.."/1/test",
									payload = "testing QoS 1",
									qos = 1,
									properties = properties,
									user_properties = user_properties,
									callback = function()
										acknowledge = true
										if acknowledge and test_msg_2 then
											-- done
											assert(client:disconnect())
										end
									end,
								})
							end})
						end})
					elseif msg.topic == prefix.."/1/test" then
						if case.args.version == mqtt.v50 then
							assert(type(msg.properties) == "table")
							assert.are.same(properties.message_expiry_interval, msg.properties.message_expiry_interval)
							assert(type(msg.user_properties) == "table")
							assert.are.same(user_properties.hello, msg.user_properties.hello)
						end
						assert(client:publish{
							topic = prefix.."/2/test",
							payload = "testing QoS 2",
							qos = 2,
						})
					elseif msg.topic == prefix.."/2/test" then
						test_msg_2 = true
						if acknowledge and test_msg_2 then
							-- done
							assert(client:disconnect())
						end
					end
				end,

				error = function(err)
					errors[#errors + 1] = err
				end,

				close = function(conn)
					close_reason = conn.close_reason
				end,
			}

			-- and wait for connection to broker is closed
			if case.sync then
				mqtt.run_sync(client)
			else
				mqtt.run_ioloop(client)
			end

			assert.are.same({}, errors)
			assert.is_true(acknowledge)
			assert.are.same(close_reason, "connection closed by client")
		end)
	end
end)

describe("last will message", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	-- common topics prefix with random part
	local prefix = "luamqtt/"..tostring(math.floor(math.random()*1e13))

	local will_topic = prefix.."/willtest"

	it("should be received", function()
		local client1 = mqtt.client{
			uri = "mqtt.flespi.io",
			clean = true,
			-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
			username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
			will = { topic=will_topic, payload="will payload", qos=1 },
		}
		local client2 = mqtt.client{
			uri = "mqtt.flespi.io",
			clean = true,
			-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
			username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
		}

		local client1_ready, client2_ready

		local function send_self_destroy()
			if not client1_ready or not client2_ready then
				return
			end
			assert(client1:publish{
				topic = prefix.."/stop",
				payload = "self-destructing-message",
			})
		end

		client1:on{
			connect = function()
				-- subscribe, then send self-destructing message
				assert(client1:subscribe{topic=prefix.."/stop", callback=function()
					client1_ready = true
					send_self_destroy()
				end})
			end,
			message = function()
				-- break connection with broker on any message
				client1:close_connection("self-destructed")
			end,
		}

		local will_received

		client2:on{
			connect = function()
				-- subscribe to will-message topic
				assert(client2:subscribe{topic=will_topic, callback=function()
					client2_ready = true
					send_self_destroy()
				end})
			end,
			message = function(msg)
				will_received = msg.topic == will_topic
				client2:disconnect()
			end,
		}

		mqtt.run_ioloop(client1, client2)

		assert.is_true(will_received)
	end)
end)


describe("no_local flag for subscription: ", function()
	local mqtt = require("mqtt")
	local prefix = "luamqtt/" .. tostring(math.floor(math.random()*1e13))
	local no_local_topic = prefix .. "/no_local_test"

	-- NOTE: more about flespi tokens:
	-- https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	local flespi_token = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"
	local conn_args = {
		uri = "mqtt.flespi.io",
		clean = true,
		username = flespi_token,
		version = mqtt.v50
	}

	it("msg should not be received", function()
		local c1 = mqtt.client(conn_args)
		local c2 = mqtt.client(conn_args)

		local s1 = {
			connected = false,
			subscribed = false,
			published = 0,
			messages = {},
			errors = {},
			close_reason = ""
		}
		local s2 = {
			connected = false,
			subscribed = false,
			published = 0,
			messages = {},
			errors = {},
			close_reason = ""
		}

		local function send()
			if not s1.subscribed or not s2.subscribed then
				return
			end
			assert(c1:publish{
				topic = no_local_topic,
				payload = "message",
				callback = function()
					s1.published = s1.published + 1
				end
			})
		end

		c1:on{
			connect = function()
				s1.connected = true
				send()
				assert(c1:subscribe{
					topic = prefix .. "/#",
					no_local = true,
					callback = function()
						s1.subscribed = true
						send()
					end
				})
			end,
			message = function(msg)
				s1.messages[#s1.messages + 1] = msg.payload
				if msg.payload == "stop" then
					assert(c1:disconnect())
				end
			end,
			error = function(err)
				s1.errors[#s1.errors + 1] = err
			end,
			close = function(conn)
				s1.close_reason = conn.close_reason
			end
		}

		c2:on{
			connect = function()
				s2.connected = true
				assert(c2:subscribe{
					topic = no_local_topic,
					no_local = false,
					callback = function()
						s2.subscribed = true
						send()
					end
				})
			end,
			message = function(msg)
				s2.messages[#s2.messages + 1] = msg.payload
				if msg.payload == "message" then
					assert(c2:publish{
						topic = no_local_topic,
						payload = "stop",
						callback = function()
							s2.published = s2.published + 1
						end
					})
				elseif msg.payload == "stop" then
					assert(c2:disconnect())
				end
			end,
			error = function(err)
				s2.errors[#s2.errors + 1] = err
			end,
			close = function(conn)
				s2.close_reason = conn.close_reason
			end
		}

		mqtt.run_ioloop(c1, c2)

		assert.is_true(s1.connected, "client 1 is not connected")
		assert.is_true(s2.connected, "client 2 is not connected")
		assert.is_true(s1.subscribed, "client 1 is not subscribed")
		assert.is_true(s2.subscribed, "client 2 is not subscribed")
		assert.are.equal(1, s1.published, "only one publish")
		assert.are.equal(1, s2.published, "only one publish")
		assert.are.same({"stop"}, s1.messages, "only one message")
		assert.are.same({"message", "stop"}, s2.messages, "should be two messages")
		assert.are.same({}, s1.errors, "errors occured with client 1")
		assert.are.same({}, s2.errors, "errors occured with client 2")
	end)
end)

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

			connector = require("mqtt.luasocket-copas"),
		}

		client:on{
			connect = function()
				-- print("client connected")
				assert(client:subscribe{topic=prefix.."/copas", qos=1, callback=function()
					-- print("subscribed")
					copas.sleep(2)
					assert(client:publish{
						topic = prefix.."/copas",
						payload = "copas test",
						qos = 1,
					})
				end})
			end,

			message = function(msg)
				assert(client:acknowledge(msg))
				-- print("received", msg)
				if msg.topic == prefix.."/copas" and msg.payload == "copas test" then
					-- print("disconnect")
					assert(client:disconnect())
				end
			end
		}

		local ticks = 0
		local mqtt_finished = false

		copas.addthread(function()
			mqtt.run_sync(client)
			mqtt_finished = true
			assert.is_true(ticks > 1, "expecting mqtt client run takes at least one tick")
		end)

		copas.addthread(function()
			for _ = 1, 3 do
				copas.sleep(1)
				ticks = ticks + 1
			end
		end)

		copas.loop()

		assert.is_true(mqtt_finished, "expecting mqtt client to finish its work")
		assert.is_true(ticks == 3, "expecting 3 ticks")
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
