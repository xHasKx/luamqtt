-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html
-- DOC v5.0: http://docs.oasis-open.org/mqtt/mqtt/v5.0/cos01/mqtt-v5.0-cos01.html

local log = require("logging").defaultLogger()
local socket = require("socket")

describe("MQTT lua library", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	it("has .client function", function()
		assert.are.equal("function", type(mqtt.client))
	end)
end)



describe("uri parsing:", function()

	-- @param opts uri string, or options table
	-- @param expected_conn expected connection table after parsing
	-- @param expected_opts (optional) if given expected options table after parsing
	local function try(opts, expected_conn, expected_opts)
		-- reload client in test mode
		_G._TEST = true
		package.loaded["mqtt.client"] = nil
		local client = require("mqtt.client")

		if type(opts) == "string" then
			opts = { uri = opts }
		end
		local conn = {
			uri = opts.uri
		}

		client.__parse_connection_opts(opts, conn)

		expected_conn.uri = opts.uri -- must remain the same anyway, so add here
		conn.secure_params = nil  -- not validating those
		assert.same(expected_conn, conn)

		if expected_opts then
			expected_opts.uri = opts.uri -- must remain the same anyway, so add here
			assert.same(expected_opts, opts)
		end
		return conn, opts
	end


	describe("valid uri strings", function()

		it("protocol+user+password+host+port", function()
			try("mqtts://usr:pwd@host.com:123", {
				-- expected conn
				host = "host.com",
				port = 123,
				protocol = "mqtts",
				secure = true,
				ssl_module = "ssl",
			}, {
				-- expected opts
				password = "pwd",
				secure = true,  -- was set because of protocol
				username = "usr",
			})
		end)

		it("user+password+host+port", function()
			try("usr:pwd@host.com:123", {
				-- expected conn
				host = "host.com",
				port = 123,
				protocol = "mqtt",
				secure = false,
				ssl_module = nil,
			}, {
				-- expected opts
				password = "pwd",
				secure = nil,
				username = "usr",
			})
		end)

		it("protocol+host+port", function()
			try("mqtts://host.com:123", {
				-- expected conn
				host = "host.com",
				port = 123,
				protocol = "mqtts",
				secure = true,
				ssl_module = "ssl",
			}, {
				-- expected opts
				secure = true,  -- was set because of protocol
			})
		end)

		it("host+port", function()
			try("host.com:123", {
				-- expected conn
				host = "host.com",
				port = 123,
				protocol = "mqtt",
				secure = false,
				ssl_module = nil,
			}, {
				-- expected opts
			})
		end)

		it("host only", function()
			try("host.com", {
				-- expected conn
				host = "host.com",
				port = 1883,  -- default port
				protocol = "mqtt",
				secure = false,
				ssl_module = nil,
			}, {
				-- expected opts
			})
		end)

	end)


	it("uri properties are overridden by specific properties", function()
		try({
			uri = "mqtt://usr:pwd@host.com:123",
			host = "another.com",
			port = 456,
			protocol = "mqtt",
			password = "king",
			username = "arthur",
		}, {
			-- expected conn
			host = "another.com",
			port = 456,
			protocol = "mqtt",
			secure = false,
			ssl_module = nil,
		}, {
			-- expected opts
			host = "another.com",
			port = 456,
			protocol = "mqtt",
			password = "king",
			secure = false,
			username = "arthur",
		})
	end)

end)



describe("invalid arguments to mqtt.client constructor", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	it("argument table key is not a string", function()
		assert.has_error(function() mqtt.client{1} end, "expecting string key in opts, got: number")
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
		assert.has_error(function() mqtt.client{unexpected=true} end, "unexpected key in client opts: unexpected = true")
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
			connector = require("mqtt.connector.luasocket"),
			ssl_module = "ssl",
		}
	end)
end)

describe("MQTT client", function()
	-- load MQTT lua library
	local mqtt = require("mqtt")

	-- initializing random numbers generator to make unique client_id's
	math.randomseed(os.time())

	-- test servers
	local cases = {
		{
			name = "mqtt.flespi.io PLAIN, MQTT v3.1.1",
			args = {
				-- id = "luamqtt-test-flespi", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.flespi.io",
				clean = true,
				-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
				username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
			}
		},
		{
			name = "mqtt.flespi.io PLAIN+sync, MQTT v3.1.1",
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
			name = "mqtt.flespi.io SECURE, MQTT v3.1.1",
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
			name = "mqtt.flespi.io PLAIN, MQTT v5.0",
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
			name = "mqtt.flespi.io SECURE, MQTT v5.0",
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
		-- NOTE: test.mosquitto.org is not working sometimes (or maybe they're treating this tests as a spam/ddos)
		--[[
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
		--[[ -- NOTE: looks like mqtt.fluux.io is no more a public MQTT broker...
		{
			name = "mqtt.fluux.io PLAIN, MQTT v3.1.1",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				clean = true,
			}
		},
		{
			name = "mqtt.fluux.io SECURE, MQTT v3.1.1",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				secure = true,
				clean = true,
			}
		},
		{
			name = "mqtt.fluux.io PLAIN, MQTT v5.0",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				clean = true,
				version = mqtt.v50,
			}
		},
		{
			name = "mqtt.fluux.io SECURE, MQTT v5.0",
			args = {
				-- id = "luamqtt-test-fluux", -- do not use fixed client id to allow simultaneous tests run (Travis CI)
				uri = "mqtt.fluux.io",
				secure = true,
				clean = true,
				version = mqtt.v50,
			}
		},
		]]
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
			client:on("connect", function(packet)
				log:warn("connect: %d %s", packet.rc, packet:reason_string())
				assert(packet.rc == 0, packet:reason_string())
				assert(client:send_pingreq()) -- NOTE: not required, it's here only to improve code coverage
				log:warn("subscribing to '.../0/test'")
				assert(client:subscribe{topic=prefix.."/0/test", callback=function()
					log:warn("subscription to '.../0/test' confirmed")
					log:warn("now publishing 'initial' to '.../0/test'")
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
						log:warn("received message on '.../0/test', payload: %s", msg.payload)
						log:warn("unsubscribing from '.../0/test'")
						assert(client:unsubscribe{topic=prefix.."/0/test", callback=function()
							log:warn("unsubscribe from '.../0/test' confirmed")
							log:warn("subscribing to '.../#'")
							assert(client:subscribe{topic=prefix.."/#", qos=2, callback=function()
								log:warn("subscription to '.../#' confirmed")
								log:warn("now publishing 'testing QoS 1' to '.../1/test'")
								assert(client:publish{
									topic = prefix.."/1/test",
									payload = "testing QoS 1",
									qos = 1,
									properties = properties,
									user_properties = user_properties,
									callback = function()
										log:warn("publishing 'testing QoS 1' to '.../1/test' confirmed")
										acknowledge = true
										if acknowledge and test_msg_2 then
											-- done
											log:warn("both `acknowledge` (by me) and `test_msg_2` are set, disconnecting now")
											assert(client:disconnect())
										else
											log:warn("only `acknowledge` (by me) is set, not `test_msg_2`. So not disconnecting yet")
										end
									end,
								})
							end})
						end})
					elseif msg.topic == prefix.."/1/test" then
						log:warn("received message on '.../1/test', payload: %s", msg.payload)
						if case.args.version == mqtt.v50 then
							assert(type(msg.properties) == "table")
							assert.are.same(properties.message_expiry_interval, msg.properties.message_expiry_interval)
							assert(type(msg.user_properties) == "table")
							assert.are.same(user_properties.hello, msg.user_properties.hello)
						end
						log:warn("now publishing 'testing QoS 2' to '.../2/test'")
						assert(client:publish{
							topic = prefix.."/2/test",
							payload = "testing QoS 2",
							qos = 2,
							callback = function()
								log:warn("publishing 'testing QoS 2' to '.../2/test' confirmed")
							end,
						})
					elseif msg.topic == prefix.."/2/test" then
						log:warn("received message on '.../2/test', payload: %s", msg.payload)
						test_msg_2 = true
						if acknowledge and test_msg_2 then
							-- done
							log:warn("both `test_msg_2` (by me) and `acknowledge` (by me) are set, disconnecting now")
							assert(client:disconnect())
						else
							log:warn("only `test_msg_2` (by me) is set, not `acknowledge`. So not disconnecting yet")
						end
					end
				end,

				error = function(err)
					errors[#errors + 1] = err
				end,

				close = function(conn)
					close_reason = conn.close_reason
					-- remove our client from the loop to make it exit.
					require("mqtt.ioloop").get():remove(client)
				end,
			}

			-- and wait for connection to broker to be closed
			mqtt.run_ioloop(client)

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

		local client1_ready, client2_ready, clients_done

		local function send_self_destroy()
			if not client1_ready or not client2_ready then
				log:warn("not self destroying, clients not ready")
				return
			end
			log:warn("client1 publishing 'self-destructing-message' to '.../stop' topic")
			assert(client1:publish{
				topic = prefix.."/stop",
				payload = "self-destructing-message",
			})
		end

		client1:on{
			connect = function()
				-- subscribe, then send self-destructing message
				log:warn("client1 is now connected")
				log:warn("client1 subscribing to '.../stop' topic")
				assert(client1:subscribe{topic=prefix.."/stop", callback=function()
					client1_ready = true
					log:warn("client1 subscription to '.../stop' topic confirmed, client 1 is ready for self destruction")
					send_self_destroy()
				end})
			end,
			message = function()
				-- break connection with broker on any message
				log:warn("client1 received a message and is now closing its connection")
				client1:close_connection("self-destructed")
				clients_done = (clients_done or 0)+1
			end,
		}

		local will_received

		client2:on{
			connect = function()
				-- subscribe to will-message topic
				log:warn("client2 is now connected")
				log:warn("client2 subscribing to will-topic: '.../willtest' topic")
				assert(client2:subscribe{topic=will_topic, callback=function()
					client2_ready = true
					log:warn("client2 subscription to will-topic '.../willtest' confirmed, client 2 is ready for self destruction")
					send_self_destroy()
				end})
			end,
			message = function(msg)
				will_received = msg.topic == will_topic
				log:warn("client2 received a message, topic is: '%s', client 2 is now closing its connection",tostring(msg.topic))
				client2:disconnect()
				clients_done = (clients_done or 0)+1
			end,
		}

		local timer do
			local timeout = socket.gettime() + 30
			function timer()
				if clients_done == 2 then
					require("mqtt.ioloop").get():remove(timer)
				end
				assert(socket.gettime() < timeout, "test failed due to timeout")
			end
		end

		mqtt.run_ioloop(client1, client2, timer)

		assert.is_true(will_received)
	end)
end)


describe("no_local flag for subscription:", function()
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
				log:warn("not sending because clients are not both subscribed")
				return
			end
			log:warn("both clients are subscribed, now sending...")
			socket.sleep(0.2) -- shouldn't be necessary, but test is flaky otherwise
			log:warn("client1: publishing 'message' to topic '.../no_local_test'")
			assert(c1:publish{
				topic = no_local_topic,
				payload = "message",
				callback = function()
					s1.published = s1.published + 1
					log:warn("client1: publishing to topic '.../no_local_test' confirmed, count: %d", s1.published)
				end
			})
		end

		c1:on{
			connect = function()
				log:warn("client1: is now connected")
				s1.connected = true
				send()
				log:warn("client1: subscribing to topic '.../#', with 'no_local'")
				assert(c1:subscribe{
					topic = prefix .. "/#",
					no_local = true,
					callback = function()
						s1.subscribed = true
						log:warn("client1: subscription to topic '.../#' with 'no_local' confirmed")
						send()
					end
				})
			end,
			message = function(msg)
				s1.messages[#s1.messages + 1] = msg.payload
				if msg.payload == "stop" then
					log:warn("client1: received message, with payload 'stop'. Will now disconnect.")
					assert(c1:disconnect())
				else
					log:warn("client1: received message, with payload '%s' (but waiting for 'stop')", msg.payload)
				end
			end,
			error = function(err)
				s1.errors[#s1.errors + 1] = err
				log:warn("client1: received error: '%s'", tostring(err))
			end,
			close = function(conn)
				log:warn("client1: closed, reason: %s", conn.close_reason)
				s1.close_reason = conn.close_reason
			end
		}

		c2:on{
			connect = function()
				s2.connected = true
				log:warn("client2: is now connected")
				log:warn("client2: subscribing to topic '.../#', without 'no_local'")
				assert(c2:subscribe{
					topic = no_local_topic,
					no_local = false,
					callback = function()
						s2.subscribed = true
						log:warn("client2: subscription to topic '.../#' without 'no_local' confirmed")
						send()
					end
				})
			end,
			message = function(msg)
				s2.messages[#s2.messages + 1] = msg.payload
				if msg.payload == "message" then
					log:warn("client2: received message, with payload 'message'")
					log:warn("client2: publishing to topic '.../no_local_test'', with payload 'stop'")
					assert(c2:publish{
						topic = no_local_topic,
						payload = "stop",
						callback = function()
							s2.published = s2.published + 1
							log:warn("client2: publishing to topic '.../no_local_test' confirmed, count: %d", s2.published)
						end
					})
				elseif msg.payload == "stop" then
					log:warn("client2: received message, with payload 'stop'. Will now disconnect.")
					assert(c2:disconnect())
				else
					log:warn("client2: received message, with payload '%s' (but waiting for 'stop' or 'message')", msg.payload)
				end
			end,
			error = function(err)
				s2.errors[#s2.errors + 1] = err
			end,
			close = function(conn)
				s2.close_reason = conn.close_reason
			end
		}

		local timer do
			local timeout = socket.gettime() + 30
			function timer()
				if s1.close_reason and s2.close_reason then
					require("mqtt.ioloop").get():remove(timer)
				end
				assert(socket.gettime() < timeout, "test failed due to timeout")
			end
		end

		mqtt.run_ioloop(c1, c2, timer)

		assert.is_true(s1.connected, "client 1 is not connected")
		assert.is_true(s2.connected, "client 2 is not connected")
		assert.is_true(s1.subscribed, "client 1 is not subscribed")
		assert.is_true(s2.subscribed, "client 2 is not subscribed")
		assert.are.equal(1, s1.published, "only one publish")
		assert.are.equal(1, s2.published, "only one publish")
		assert.are.same({"stop"}, s1.messages, "only one message")
		assert.are.same({"message", "stop"}, s2.messages, "should be two messages")
		assert.are.same({}, s1.errors, "errors occurred with client 1")
		assert.are.same({}, s2.errors, "errors occurred with client 2")
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
