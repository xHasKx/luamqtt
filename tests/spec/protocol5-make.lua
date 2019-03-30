-- busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/protocol5-make.lua
-- DOC: https://docs.oasis-open.org/mqtt/mqtt/v5.0/cos02/mqtt-v5.0-cos02.html

describe("MQTT v5.0 protocol: making packets", function()
	local tools = require("mqtt.tools")
	local extract_hex = require("./tests/extract_hex")
	local protocol = require("mqtt.protocol")
	local protocol5 = require("mqtt.protocol5")

	it("CONNECT with minimum params", function()
		assert.are.equal(
			extract_hex[[
				10						-- packet type == 1 (CONNECT), flags == 0
				18						-- length == 0x18 == 24 bytes

											-- next is 24 bytes for variable header and payload:

					0004 4D515454			-- protocol name == "MQTT"
					05						-- protocol version == 5 for MQTT v5.0
					00						-- connect flags == 0: reserved=0, clean=0, will=0, will_qos=0, will_retaion=0, password=0, username=0
					0000					-- keep alive
					00						-- connect properties length

												-- next is payload

						000B 636C69656E742D69642D35		-- client id string
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.CONNECT,
				id = "client-id-5",
			}))
		)
	end)

	it("CONNECT with some params", function()
		assert.are.equal(
			extract_hex[[
				10						-- packet type == 1 (CONNECT), flags == 0
				18						-- length == 0x18 == 24 bytes

											-- next is 24 bytes for variable header and payload:

					0004 4D515454			-- protocol name == "MQTT"
					05						-- protocol version == 5 for MQTT v5.0
					02						-- connect flags == 2: reserved=0, clean=1, will=0, will_qos=0, will_retaion=0, password=0, username=0
					00FF					-- keep alive == 0xFF
					00						-- connect properties length

												-- next is payload

						000B 636C69656E742D69642D35		-- client id string
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.CONNECT,
				id = "client-id-5",
				clean = true,
				keep_alive = 0xFF,
			}))
		)
	end)

	it("CONNECT with full params and no properties", function()
		assert.are.equal(
			extract_hex[[
				10						-- packet type == 1 (CONNECT), flags == 0
				55						-- length == 0x55 == 85 bytes

											-- next is 85 bytes for variable header and payload:

					0004 4D515454		-- protocol name == "MQTT"
					05					-- protocol version == 5 for MQTT v5.0
					F6					-- connect flags == 0xF6: reserved=0, clean=1, will=1, will_qos=2, will_retaion=1, password=1, username=1
					001E				-- keep alive == 0x1E == 30
					00					-- connect properties length

											-- next is payload:

					000B 636C69656E742D69642D35			-- client id == "client-id-5"
					00									-- will properties length == 0
					0007 6F66666C696E65					-- will topic == "offline"
					0016 636C69656E742D69642D35206973206F66666C696E65	-- will payload: "client-id-5 is offline"
					000A 54686520352D55736572			-- user name
					000D 3535352D546F70536563726574		-- password
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.CONNECT,
				id = "client-id-5",
				clean = true,
				will = {
					payload = "client-id-5 is offline",
					topic = "offline",
					qos = 2,
					retain = true,
				},
				username = "The 5-User",
				password = "555-TopSecret",
				keep_alive = 30,
			}))
		)
	end)

	it("CONNECT with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				10						-- packet type == 1 (CONNECT), flags == 0
				EF01					-- length == 0xEF01 as variable length field == 239 bytes

											-- next is 239 bytes for variable header and payload:

					0004 4D515454			-- protocol name == "MQTT"
					05						-- protocol version == 5 for MQTT v5.0
					F6						-- connect flags == 0xF6: reserved=0, clean=1, will=1, will_qos=2, will_retaion=1, password=1, username=1
					001E					-- keep alive == 0x1E == 30
					4C						-- connect properties length == 76 bytes

											-- next is connect properties of 76 bytes:

					11 00015180							-- property 0x11 == 86400 -- DOC: 3.1.2.11.2 Session Expiry Interval
					15 0005 6261736963					-- property 0x15 == "basic" -- DOC: 3.1.2.11.9 Authentication Method
					16 000B 736F6D652D736563726574		-- property 0x16 == "some-secret" -- DOC: 3.1.2.11.10 Authentication Data
					17 01								-- property 0x17 == 1 -- DOC: 3.1.2.11.7 Request Problem Information
					19 01								-- property 0x19 == 1 -- DOC: 3.1.2.11.6 Request Response Information
					21 7FFF								-- property 0x21 == 32767 -- DOC: 3.1.2.11.3 Receive Maximum
					22 03E8								-- property 0x22 == 1000 -- DOC: 3.1.2.11.5 Topic Alias Maximum
					27 00100000							-- property 0x27 == 1048576 -- DOC: 3.1.2.11.4 Maximum Packet Size
					26 0004 66726F6D 000A 4D515454207465737473 -- property 0x26 (user) == ("form", "MQTT tests") -- DOC: 3.1.2.11.8 User Property
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.1.2.11.8 User Property

															-- next is payload:

						000B 636C69656E742D69642D35			-- client id == "client-id-5"
						4E									-- will properties length == 78 bytes

															-- next is 78 bytes of will message properties:

						01 01								-- property 0x01 == 1 -- DOC: 3.1.3.2.3 Payload Format Indicator
						02 00015180							-- property 0x02 == 86400 -- DOC: 3.1.3.2.4 Message Expiry Interval
						03 000A 746578742F706C61696E		-- property 0x03 == "text/plain" -- DOC: 3.1.3.2.5 Content Type
						08 000C 6F6B61792F6F66666C696E65	-- property 0x08 == "okay/offline" -- DOC: 3.1.3.2.6 Response Topic
						09 0004 736F6D65					-- property 0x09 == "some" -- DOC: 3.1.3.2.7 Correlation Data
						18 00000014							-- property 0x18 == 20 -- DOC: 3.1.3.2.2 Will Delay Interval
						26 0005 68656C6C6F 0004 776F7264	-- property 0x26 (user) == ("hello", "world") -- DOC: 3.1.3.2.8 User Property
						26 0004 736F6D65 0008 70726F7065727479	-- property 0x26 (user) == ("some", "property") -- DOC: 3.1.3.2.8 User Property

						0007 6F66666C696E65					-- will topic == "offline"
						0016 636C69656E742D69642D35206973206F66666C696E65	-- will payload == "client-id-5 is offline"
						000A 54686520352D55736572			-- username == "The 5-User"
						000D 3535352D546F70536563726574		-- password == "555-TopSecret"
			]],
			tools.hex(tostring(protocol5.make_packet{
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
			}))
		)
	end)

	it("PUBLISH with minimum params", function()
		assert.are.equal(
			extract_hex[[
				30						-- packet type == 3 (CONNECT), flags == 0: dup=0, qos=0, retain=0
				0B						-- length == 0x0B == 11 bytes

											-- next is 11 bytes for variable header and payload:

					0008 746573742F707562	-- topic == "test/pub"
					00						-- properties length
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBLISH,
				topic = "test/pub",
				qos = 0,
				retain = false,
				dup = false,
			}))
		)
	end)

	it("PUBLISH with some params without properties", function()
		assert.are.equal(
			extract_hex[[
				3D						-- packet type == 3 (CONNECT), flags == 0xD: dup=1, qos=2, retain=1
				0D						-- length == 0x0D == 13 bytes

											-- next is 13 bytes for variable header and payload:

					0008 746573742F707562	-- topic == "test/pub"
					04D2					-- packet identifier == 0x04D2 == 1234
					00						-- properties length
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBLISH,
				topic = "test/pub",
				qos = 2,
				packet_id = 1234,
				retain = true,
				dup = true,
			}))
		)
	end)

	it("PUBLISH with full params without properties", function()
		assert.are.equal(
			extract_hex[[
				33						-- packet type == 3 (CONNECT), flags == 0x3: dup=0, qos=1, retain=1
				16						-- length == 0x16 == 22 bytes

											-- next is 22 bytes for variable header and payload:

					0008 746573742F707562	-- topic == "test/pub"
					00DE					-- packet identifier == 0x00DE == 222
					00						-- properties length

					686579204D51545421		-- payload == "hey MQTT!"
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBLISH,
				topic = "test/pub",
				qos = 1,
				packet_id = 222,
				retain = true,
				dup = false,
				payload = "hey MQTT!",
			}))
		)
	end)

	it("PUBLISH with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				3D						-- packet type == 3 (CONNECT), flags == 0xD: dup=1, qos=2, retain=1
				9701					-- length == 0x9701 as variable length field == 151 bytes

											-- next is 22 bytes for variable header and payload:

					0008 746573742F707562	-- topic == "test/pub"
					00DE					-- packet identifier == 0x00DE == 222
					8001					-- properties length == 0x8001 as variable length field == 128 bytes

											-- next is 128 bytes of properties:

					01 01					-- property 0x01 == 1 -- DOC: 3.3.2.3.2 Payload Format Indicator
					02 00015180				-- property 0x02 == 86400 -- DOC: 3.3.2.3.3 Message Expiry Interval
					03 000A 796F752F74656C6C6D65 -- property 0x03 == "you/tellme" -- DOC: 3.3.2.3.9 Content Type
					08 0004 68657265		-- property 0x08 == "here" -- DOC: 3.3.2.3.5 Response Topic
					09 0004 736F6D65		-- property 0x09 == "some" -- DOC: 3.3.2.3.6 Correlation Data
					0B 05					-- property 0x0B == 5 -- DOC: 3.3.2.3.8 Subscription Identifier
					23 1234					-- property 0x23 == 0x1234 -- DOC: 3.3.2.3.4 Topic Alias
					26 000B 546F20496E66696E697479 000A 616E64204265796F6E64	-- property 0x26 (user) == ("To Infinity", "and Beyond") -- DOC: 3.3.2.3.7 User Property
					26 0005 6172726179 0006 6974656D2031	-- property 0x26 (user) == ("array", "item 1") -- DOC: 3.3.2.3.7 User Property
					26 0005 6172726179 0006 6974656D2033	-- property 0x26 (user) == ("array", "item 3") -- DOC: 3.3.2.3.7 User Property
					26 0005 6172726179 0006 6974656D2032	-- property 0x26 (user) == ("array", "item 2") -- DOC: 3.3.2.3.7 User Property
					26 0005 68656C6C6F 0005 776F726C64		-- property 0x26 (user) == ("hello", "world") -- DOC: 3.3.2.3.7 User Property

					686579204D51545421		-- payload == "hey MQTT!"
			]],
			tools.hex(tostring(protocol5.make_packet{
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
					{"array", "item 1"},
					{"array", "item 3"},
					{"array", "item 2"},
					["To Infinity"] = "and Beyond",
				},
			}))
		)
	end)

	it("PUBACK with minimum params", function()
		assert.are.equal(
			extract_hex[[
				40						-- packet type == 4 (PUBACK), flags == 0
				02						-- length == 0x02 == 2 bytes

											-- next is 2 bytes of variable header:

					000A					-- packet_id == 10
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 10,
				rc = 0,
			}))
		)
	end)

	it("PUBACK with full params without properties", function()
		assert.are.equal(
			extract_hex[[
				40						-- packet type == 4 (PUBACK), flags == 0
				04						-- length == 0x04 == 4 bytes

											-- next is 4 bytes of variable header:

					000A					-- packet_id == 10
					80						-- reason code == 0x80
					00						-- properties length
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 10,
				rc = 0x80,
			}))
		)
	end)

	it("PUBACK with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				40						-- packet type == 4 (PUBACK), flags == 0
				23						-- length == 0x23 == 35 bytes

											-- next is 35 bytes of variable header:

					000A					-- packet_id == 10
					80						-- reason code == 0x80
					1F						-- properties length == 31 bytes

											-- next is 31 bytes of properties:

					1F 000D 74657374696E672070726F7073	-- property 0x1F == "testing props" -- DOC: 3.4.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world") -- DOC: 3.4.2.2.3 User Property
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 10,
				rc = 0x80,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				}
			}))
		)
	end)

	it("PUBREC with minimum params", function()
		assert.are.equal(
			extract_hex[[
				50						-- packet type == 5 (PUBREC), flags == 0
				02						-- length == 0x02 == 2 bytes

											-- next is 2 bytes of variable header:

					0016					-- packet_id == 22
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 22,
				rc = 0,
			}))
		)
	end)

	it("PUBREC with full params without properties", function()
		assert.are.equal(
			extract_hex[[
				50						-- packet type == 5 (PUBREC), flags == 0
				04						-- length == 0x04 == 4 bytes

											-- next is 4 bytes of variable header:

					0016					-- packet_id == 22
					10						-- reason code == 0x10
					00						-- properties length
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 22,
				rc = 0x10,
			}))
		)
	end)

	it("PUBREC with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				50						-- packet type == 5 (PUBREC), flags == 0
				23						-- length == 0x23 == 35 bytes

											-- next is 35 bytes of variable header:

					000A					-- packet_id == 10
					80						-- reason code == 0x80
					1F						-- properties length == 31 bytes

											-- next is 31 bytes of properties:

					1F 000D 74657374696E672070726F7073	-- property 0x1F == "testing props" -- DOC: 3.4.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world") -- DOC: 3.4.2.2.3 User Property
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 10,
				rc = 0x80,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				}
			}))
		)
	end)

	it("PUBREL with minimum params", function()
		assert.are.equal(
			extract_hex[[
				62						-- packet type == 6 (PUBREL), flags == 2 (fixed value)
				02						-- length == 0x02 == 2 bytes

											-- next is 2 bytes of variable header:

					0016					-- packet_id == 22
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 22,
				rc = 0,
			}))
		)
	end)

	it("PUBREL with full params without properties", function()
		assert.are.equal(
			extract_hex[[
				62						-- packet type == 6 (PUBREL), flags == 2 (fixed value)
				04						-- length == 0x04 == 4 bytes

											-- next is 4 bytes of variable header:

					0016					-- packet_id == 22
					92						-- reason code == 0x92
					00						-- properties length
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 22,
				rc = 0x92,
			}))
		)
	end)

	it("PUBREL with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				62						-- packet type == 6 (PUBREL), flags == 2 (fixed value)
				23						-- length == 0x23 == 35 bytes

											-- next is 35 bytes of variable header:

					000A					-- packet_id == 10
					92						-- reason code == 0x92
					1F						-- properties length == 31 bytes

											-- next is 31 bytes of properties:

					1F 000D 74657374696E672070726F7073	-- property 0x1F == "testing props" -- DOC: 3.4.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world") -- DOC: 3.4.2.2.3 User Property
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 10,
				rc = 0x92,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				}
			}))
		)
	end)

	it("PUBCOMP with minimum params", function()
		assert.are.equal(
			extract_hex[[
				70						-- packet type == 7 (PUBCOMP), flags == 0
				02						-- length == 0x02 == 2 bytes

											-- next is 2 bytes of variable header:

					0016					-- packet_id == 22
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 22,
				rc = 0,
			}))
		)
	end)

	it("PUBCOMP with full params without properties", function()
		assert.are.equal(
			extract_hex[[
				70						-- packet type == 7 (PUBCOMP), flags == 0
				04						-- length == 0x04 == 4 bytes

											-- next is 4 bytes of variable header:

					0016					-- packet_id == 22
					92						-- reason code == 0x92
					00						-- properties length
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 22,
				rc = 0x92,
			}))
		)
	end)

	it("PUBCOMP with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				70						-- packet type == 7 (PUBCOMP), flags == 0
				23						-- length == 0x23 == 35 bytes

											-- next is 35 bytes of variable header:

					000A					-- packet_id == 10
					92						-- reason code == 0x92
					1F						-- properties length == 31 bytes

											-- next is 31 bytes of properties:

					1F 000D 74657374696E672070726F7073	-- property 0x1F == "testing props" -- DOC: 3.4.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world") -- DOC: 3.4.2.2.3 User Property
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 10,
				rc = 0x92,
				properties = {
					reason_string = "testing props",
				},
				user_properties = {
					hello = "world",
				}
			}))
		)
	end)

	it("SUBSCRIBE with minimum params", function()
		assert.are.equal(
			extract_hex[[
				82						-- packet type == 8 (SUBSCRIBE), flags == 2 (fixed value)
				0A						-- length == 0x0A == 10 bytes

											-- next is 10 bytes of variable header and payload:

					0003					-- packet_id == 3
					00						-- properties length

											-- payload:

					0004 74657374			-- topic "test"
					00						-- subscription options == qos=0, no_local=0, retain_as_published=0, retain_handling=0
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 3,
				subscriptions = {
					{
						topic = "test",
						no_local = false,
						retain_as_published = false,
						retain_handling = 0,
					},
				},
			}))
		)
	end)

	it("SUBSCRIBE with full params, several topics and without properties", function()
		assert.are.equal(
			extract_hex[[
				82						-- packet type == 8 (SUBSCRIBE), flags == 2 (fixed value)
				12						-- length == 0x12 == 18 bytes

											-- next is 18 bytes of variable header and payload:

					0004					-- packet_id == 4
					00						-- properties length

											-- payload:

					0004 74657374			-- topic "test"
					2E						-- subscription options == qos=2, no_local=1, retain_as_published=1, retain_handling=2
					0005 6F74686572			-- topic "other"
					15						-- subscription options == qos=1, no_local=1, retain_as_published=0, retain_handling=1
			]],
			tools.hex(tostring(protocol5.make_packet{
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
			}))
		)
	end)

	it("SUBSCRIBE with full params, several topics and full properties", function()
		assert.are.equal(
			extract_hex[[


				82						-- packet type == 8 (SUBSCRIBE), flags == 2 (fixed value)
				24						-- length == 0x24 == 36 bytes

											-- next is 36 bytes of variable header and payload:

					0004					-- packet_id == 4
					12						-- properties length == 0x12 == 18 bytes

											-- next is 18 bytes of properties:

					0B C546					-- property 0x0B == 0xC546 as variable length field == 0x2345 == 9029 -- DOC: 3.8.2.1.2 Subscription Identifier
					26 0005 68656C6C6F 0005 616761696E	-- property 0x26 (user) == ("hello", "again") -- DOC: 3.8.2.1.3 User Property

											-- payload:

					0004 74657374			-- topic "test"
					2E						-- subscription options == qos=2, no_local=1, retain_as_published=1, retain_handling=2
					0005 6F74686572			-- topic "other"
					15						-- subscription options == qos=1, no_local=1, retain_as_published=0, retain_handling=1
			]],
			tools.hex(tostring(protocol5.make_packet{
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
			}))
		)
	end)

	it("UNSUBSCRIBE with full params", function()
		assert.are.equal(
			extract_hex[[
				A2						-- packet type == 0xA == 10 (UNSUBSCRIBE), flags == 2 (fixed value)
				0A						-- length == 0x0A == 10 bytes

											-- next is 10 bytes of variable header and payload:

					000E					-- packet_id == 3
					00						-- properties length

											-- payload:

					0005 6F74686572			-- topic "other"
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.UNSUBSCRIBE,
				packet_id = 14,
				subscriptions = {
					"other",
				},
			}))
		)
	end)

	it("UNSUBSCRIBE with full params, several topics and full properties", function()
		assert.are.equal(
			extract_hex[[
				A2						-- packet type == 0xA == 10 (UNSUBSCRIBE), flags == 2 (fixed value)
				30						-- length == 0x0A == 10 bytes

											-- next is 10 bytes of variable header and payload:

					000E					-- packet_id == 3
					20						-- properties length == 32 bytes

											-- next is 32 bytes of properties:

					26 0006 627965627965 0005 776F726C64	-- property 0x26 (user) == ("byebye", "world") -- DOC: 3.10.2.1.2 User Property
					26 0006 627965627965 0005 616761696E	-- property 0x26 (user) == ("byebye", "again") -- DOC: 3.10.2.1.2 User Property

											-- payload:

					0005 6F74686572			-- topic "other"
					0004 74657374			-- topic "test"
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.UNSUBSCRIBE,
				packet_id = 14,
				subscriptions = {
					"other",
					"test"
				},
				user_properties = {
					{"byebye", "world"},
					{"byebye", "again"},
				},
			}))
		)
	end)

	it("PINGREQ", function()
		assert.are.equal(
			extract_hex[[
				C0						-- packet type == 0xC == 12 (PINGREQ), flags == 0
				00						-- length == 0x00 == 0 bytes
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.PINGREQ,
			}))
		)
	end)

	it("DISCONNECT with minimum params", function()
		assert.are.equal(
			extract_hex[[
				E0						-- packet type == 0xE == 14 (DISCONNECT), flags == 0
				00						-- length == 0x00 == 0 bytes
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.DISCONNECT,
				rc = 0,
			}))
		)
	end)

	it("DISCONNECT with full params and without properties", function()
		assert.are.equal(
			extract_hex[[
				E0						-- packet type == 0xE == 14 (DISCONNECT), flags == 0
				02						-- length == 0x02 == 2 bytes

											-- next is 2 bytes of variable header:

					81						-- reason code == 0x81
					00						-- properties length == 0 bytes
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.DISCONNECT,
				rc = 0x81,
			}))
		)
	end)

	it("DISCONNECT with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				E0						-- packet type == 0xE == 14 (DISCONNECT), flags == 0
				2B						-- length == 0x2B == 43 bytes

											-- next is 43 bytes of variable header:

					87						-- reason code == 0x87
					29						-- properties length 0x29 == 41 bytes

											-- next is 41 bytes of properties:

					11 00000E10				-- property 0x11 == 3600 -- DOC: 3.14.2.2.2 Session Expiry Interval
					1C 0002 3433			-- property 0x1C == "43" -- DOC: 3.14.2.2.5 Server Reference
					1F 0008 66696E616C6C7921	-- property 0x1F == "finally!" -- DOC: 3.14.2.2.3 Reason String
					26 0006 736572766572 0009 6E6F742034323F3F3F	-- property 0x26 (user) == ("server", "not 42???") -- DOC: 3.14.2.2.4 User Property
			]],
			tools.hex(tostring(protocol5.make_packet{
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
			}))
		)
	end)

	it("AUTH with minimum params", function()
		assert.are.equal(
			extract_hex[[
				F0						-- packet type == 0xE == 14 (AUTH), flags == 0
				00						-- length == 0x00 == 0 bytes
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.AUTH,
				rc = 0,
			}))
		)
	end)

	it("AUTH with full params without properties", function()
		assert.are.equal(
			extract_hex[[
				F0						-- packet type == 0xE == 14 (AUTH), flags == 0
				02						-- length == 0x02 == 2 bytes

											-- next is 2 bytes of variable header:

					18						-- reason code == 0x18
					00						-- properties length == 0 bytes
			]],
			tools.hex(tostring(protocol5.make_packet{
				type = protocol.packet_type.AUTH,
				rc = 0x18,
			}))
		)
	end)

	it("AUTH with full params and full properties", function()
		assert.are.equal(
			extract_hex[[
				F0						-- packet type == 0xE == 14 (AUTH), flags == 0
				3E						-- length == 0x3E == 62 bytes

											-- next is 62 bytes of variable header:

					19						-- reason code == 0x19
					3C						-- properties length == 0x3C == 60 bytes

											-- next is 60 bytes of properties:

					15 0005 6775657373		-- property 0x15 == "guess" -- DOC: 3.15.2.2.2 Authentication Method
					16 000D 343220697320746865206B6579	-- property 0x16 == "42 is the key" -- DOC: 3.15.2.2.3 Authentication Data
					1F 000A 6A757374206361757365	-- property 0x1F == "just cause" -- DOC: 3.15.2.2.4 Reason String
					26 0006 616E73776572 000C 34322C2066696E616C6C7921	-- property 0x26 (user) == ("answer", "42, finally!") -- DOC: 3.15.2.2.5 User Property
			]],
			tools.hex(tostring(protocol5.make_packet{
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
			}))
		)
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
