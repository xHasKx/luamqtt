-- busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/protocol5-make-then-parse.lua
-- DOC: https://docs.oasis-open.org/mqtt/mqtt/v5.0/cos02/mqtt-v5.0-cos02.html


describe("MQTT v3.1.1 protocol: making and then parsing back all packets", function()
	local mqtt = require("mqtt")
	local tools = require("mqtt.tools")
	local protocol = require("mqtt.protocol")
	local protocol5 = require("mqtt.protocol5")

	-- returns read_func-compatible function
	local function make_read_func_hex(hex)
		-- decode hex string into data
		local data = {}
		for i = 1, hex:len() / 2 do
			local byte = hex:sub(i*2 - 1, i*2)
			data[#data + 1] = string.char(tonumber(byte, 16))
		end
		data = table.concat(data)
		-- and return read_func
		local data_size = data:len()
		local pos = 1
		return function(size)
			if pos > data_size then
				return false, "no more data available"
			end
			local res = data:sub(pos, pos + size - 1)
			if res:len() ~= size then
				return false, "not enough unparsed data"
			end
			pos = pos + size
			return res
		end
	end

	local tests = {
		{
			title = "CONNECT",
			packet = {
				version = mqtt.v50, -- NOTE: optional field, added only to make test work
				type = protocol.packet_type.CONNECT,
				id = "client-id-5",
				clean = true,
				will = {
					payload = "client-id-5 is offline",
					topic = "offline",
					qos = 2,
					retain = true,
					properties = {
						will_delay_interval = 20,
						payload_format_indicator = 1,
						message_expiry_interval = 86400,
						content_type = "text/plain",
						response_topic = "okay/offline",
						correlation_data = "some",
					},
					user_properties = {
						some = "property",
						hello = "word",
					},
				},
				username = "The 5-User",
				password = "555-TopSecret",
				keep_alive = 30,
				properties = {
					session_expiry_interval = 86400,
					receive_maximum = 32767,
					maximum_packet_size = 1024 * 1024,
					topic_alias_maximum = 1000,
					request_response_information = 1,
					request_problem_information = 1,
					authentication_method = "basic",
					authentication_data = "some-secret",
				},
				user_properties = {
					hello = "world",
					from = "MQTT tests",
				},
			},
		},
		{
			title = "CONNACK",
			packet = {
				type = protocol.packet_type.CONNACK,
				sp = true, rc = 0x82,
				properties={
					session_expiry_interval = 3600,
					receive_maximum = 0x1234,
					maximum_qos = 1,
					retain_available = 1,
					maximum_packet_size = 0x4567,
					assigned_client_identifier = "slave",
					topic_alias_maximum = 0x4321,
					reason_string = "proceed",
					wildcard_subscription_available = 1,
					subscription_identifiers_available = 0,
					shared_subscription_available = 1,
					server_keep_alive = 120,
					response_information = "here/",
					server_reference = "see /dev/null",
					authentication_method = "guess",
					authentication_data = "10",
				},
				user_properties={
					hello = "again", -- NOTE: that key+value pair is equivalent of {"hello", "again"} below, thus that pair will be skipped
					{"hello", "world"},
					{"hello", "again"},
				},
			},
		},
		{
			title = "PUBLISH",
			packet = {
				type = protocol.packet_type.PUBLISH,
				topic = "test/pub",
				qos = 2,
				packet_id = 222,
				retain = true,
				dup = true,
				payload = "hey MQTT!",
				properties = {
					payload_format_indicator = 1,
					message_expiry_interval = 86400,
					topic_alias = 0x1234,
					response_topic = "here",
					correlation_data = "some",
					subscription_identifiers = {5}, -- NOTE: that property may be included several times but only from the broker side
					content_type = "you/tellme",
				},
				user_properties = {
					hello = "world",
					array = "item 2",
					{"array", "item 1"},
					{"array", "item 3"},
					{"array", "item 2"},
					["To Infinity"] = "and Beyond",
				},
			},
		},
		{
			title = "PUBACK",
			packet = {
				type = protocol.packet_type.PUBACK,
				packet_id = 10,
				rc = 0x80,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				}
			},
		},
		{
			title = "PUBREC",
			packet = {
				type = protocol.packet_type.PUBREC,
				packet_id = 10,
				rc = 0x80,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				}
			},
		},
		{
			title = "PUBREL",
			packet = {
				type = protocol.packet_type.PUBREL,
				packet_id = 10,
				rc = 0x92,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				},
			},
		},
		{
			title = "PUBCOMP",
			packet = {
				type = protocol.packet_type.PUBCOMP,
				packet_id = 10,
				rc = 0x92,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				},
			},
		},
		{
			title = "SUBSCRIBE",
			packet = {
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 4,
				subscriptions = {
					{
						topic = "test",
						qos = 2,
						no_local = true,
						retain_as_published = true,
						retain_handling = 2,
					},
					{
						topic = "other",
						qos = 1,
						no_local = true,
						retain_as_published = false,
						retain_handling = 1,
					},
				},
				properties = {
					subscription_identifiers = {0x2345},
				},
				user_properties = {
					hello = "again",
				},
			},
		},
		{
			title = "SUBACK",
			packet = {
				type = protocol.packet_type.SUBACK,
				packet_id = 14,
				rc = { 2, 1, 0, 0x80, 0x87, },
				properties = {
					reason_string = "okay",
				},
				user_properties = {
					hello = "uh no",
				},
			},
		},
		{
			title = "UNSUBSCRIBE",
			packet = {
				type = protocol.packet_type.UNSUBSCRIBE,
				packet_id = 14,
				subscriptions = {
					"other",
					"test"
				},
				properties = {},
				user_properties = {
					{"byebye", "world"},
					{"byebye", "again"},
					byebye = "again",
				},
			},
		},
		{
			title = "UNSUBACK",
			packet = {
				type = protocol.packet_type.UNSUBACK,
				packet_id = 14,
				rc = { 0, 0, 0, 0x80, 0x11, },
				properties = {
					reason_string = "okay",
				},
				user_properties = {
					hello = "world",
				},
			},
		},
		{
			title = "PINGREQ",
			packet = {
				type = protocol.packet_type.PINGREQ,
				properties = {}, user_properties = {}, -- NOTE: fields added automatically during parsing
			},
		},
		{
			title = "PINGRESP",
			packet = {
				type = protocol.packet_type.PINGRESP,
				properties = {}, user_properties = {}, -- NOTE: fields added automatically during parsing
			},
		},
		{
			title = "DISCONNECT",
			packet = {
				type = protocol.packet_type.DISCONNECT,
				rc = 0x87,
				properties = {
					session_expiry_interval = 3600,
					reason_string = "finally!",
					server_reference = "43",
				},
				user_properties = {
					server = "not 42???",
				},
			},
		},
		{
			title = "AUTH",
			packet = {
				type = protocol.packet_type.AUTH,
				rc = 0x19,
				properties = {
					authentication_method = "guess",
					authentication_data = "42 is the key",
					reason_string = "just cause",
				},
				user_properties = {
					answer = "42, finally!",
				},
			},
		},
	}

	for _, test in ipairs(tests) do
		it(test.title, function()
			local expected_packet = test.packet
			local packet_hex = tools.hex(tostring(protocol5.make_packet(expected_packet)))
			local parsed_packet = protocol5.parse_packet(make_read_func_hex(packet_hex))
			assert.are.same(expected_packet, parsed_packet)
		end)
	end
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
