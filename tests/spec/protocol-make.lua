-- busted -e 'package.path="./?/init.lua;"..package.path;' spec/*.lua
-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

describe("MQTT protocol: making packets", function()
	local tools = require("mqtt.tools")
	local protocol = require("mqtt.protocol")

	it("CONNECT with full properties", function()
		--[[
		10 						packet type == 1 (CONNECT), flags == 0
		48 						length == 0x48 == 72 bytes

									next is 72 bytes for variable header and payload:

			0004 4D515454 			protocol name == "MQTT"
			04 						protocol level (4 == v3.1.1)
			EE 						connect flags: 0xEE == 1110 1110:
										reserved == 0
										clean == 1 (true),
										will flag == 1
										will qos == 01 == 1
										will retain == 1 (true)
										password flag == 1
										username flag == 1
			001E 					keep alive == 30

										next is payload:

				0009 636C69656E742D6964 	client id == "client-id"
				0007 6F66666C696E65 		will topic == "offline"
				0014 636C69656E742D6964206973206F66666C696E65 	will message == "client-id is offline"
				0007 54686555736572 		username == "TheUser"
				0009 546F70536563726574 	password == "TopSecret"
		]]
		assert.are.equal(
			"104800044D51545404EE001E0009636C69656E742D696400076F66666C696E650014636C69656E742D6964206973206F66666C696E650007546865557365720009546F70536563726574",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.CONNECT,
				id = "client-id",
				clean = true,
				will = {
					message = "client-id is offline",
					topic = "offline",
					qos = 1,
					retain = true,
				},
				username = "TheUser",
				password = "TopSecret",
				keep_alive = 30,
			}))
		)
	end)

	-- TODO: it("CONNECT with some properties", function() end)

	it("PUBLISH with full properties", function()
		--[[
		3B 						packet type == 1 (PUBLISH), flags == 0xB == 1011 == DUP=1, QoS=1, RETAIN=1
		0F 						length == 0x0F == 15 bytes
			0004 736F6D65 			variable header: topic string "some"
			0001					packet id == 1
			7061796C6F6164 	payload: "payload"
		]]
		assert.are.equal(
			"3B0F0004736F6D6500017061796C6F6164",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBLISH,
				topic = "some",
				payload = "payload",
				qos = 1,
				retain = true,
				dup = true,
				packet_id = 1,
			}))
		)
	end)

	it("PUBLISH without payload", function()
		--[[
		3B 						packet type == 1 (PUBLISH), flags == 0xB == 1011 == DUP=1, QoS=1, RETAIN=1
		08 						length == 0x08 == 8 bytes
			0004 736F6D65 		variable header: topic string "some"
			0001					packet id == 1
		]]
		assert.are.equal(
			"3B080004736F6D650001",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBLISH,
				topic = "some",
				qos = 1,
				retain = true,
				dup = true,
				packet_id = 1,
			}))
		)
	end)

	it("PUBLISH minimal", function()
		--[[
		30 						packet type == 3 (PUBLISH), flags == 0x0 == 0000 == DUP=0, QoS=0, RETAIN=0
		06 						length == 0x06 == 6 bytes
			0004 736F6D65 		variable header: topic string "some"
		]]
		assert.are.equal(
			"30060004736F6D65",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBLISH,
				topic = "some",
				qos = 0,
				retain = false,
				dup = false,
			}))
		)
	end)

	it("PUBACK", function()
		--[[
		40 						packet type == 4 (PUBACK), flags == 0x0
		02 						length == 2 bytes
			0001 				variable header: Packet Identifier == 1
		]]
		assert.are.equal(
			"40020001",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 1,
			}))
		)
		assert.are.equal(
			"40020002",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 2,
			}))
		)
		assert.are.equal(
			"4002FFFF",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 0xFFFF,
			}))
		)
		-- invalid Packet Identifier's:
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 0,
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBACK,
				packet_id = 0xFFFF + 1,
			}
		end)
	end)

	it("PUBREC", function()
		--[[
		50 						packet type == 5 (PUBREC), flags == 0x0
		02 						length == 2 bytes
			0001 				variable header: Packet Identifier == 1
		]]
		assert.are.equal(
			"50020001",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 1,
			}))
		)
		assert.are.equal(
			"50020002",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 2,
			}))
		)
		assert.are.equal(
			"5002FFFF",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 0xFFFF,
			}))
		)
		-- invalid Packet Identifier's:
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 0,
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBREC,
				packet_id = 0xFFFF + 1,
			}
		end)
	end)

	it("PUBREL", function()
		--[[
		62 						packet type == 6 (PUBREL), flags == 0x2 (fixed value)
		02 						length == 2 bytes
			0001 				variable header: Packet Identifier == 1
		]]
		assert.are.equal(
			"62020001",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 1,
			}))
		)
		assert.are.equal(
			"62020002",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 2,
			}))
		)
		assert.are.equal(
			"6202FFFF",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 0xFFFF,
			}))
		)
		-- invalid Packet Identifier's:
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 0,
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBREL,
				packet_id = 0xFFFF + 1,
			}
		end)
	end)

	it("PUBCOMP", function()
		--[[
		70 						packet type == 7 (PUBCOMP), flags == 0x0
		02 						length == 2 bytes
			0001 				variable header: Packet Identifier == 1
		]]
		assert.are.equal(
			"70020001",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 1,
			}))
		)
		assert.are.equal(
			"70020002",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 2,
			}))
		)
		assert.are.equal(
			"7002FFFF",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 0xFFFF,
			}))
		)
		-- invalid Packet Identifier's:
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 0,
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.PUBCOMP,
				packet_id = 0xFFFF + 1,
			}
		end)
	end)

	it("SUBSCRIBE", function()
		--[[
		82 						packet type == 8 (SUBSCRIBE), flags == 0x2 (fixed value)
		09 						length == 9 bytes
			0001 				variable header: Packet Identifier == 1
				0004 736F6D65 	topic filter #1 == string "some"
				00 				QoS #1 == 0
		]]
		assert.are.equal(
			"820900010004736F6D6500",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 1,
				subscriptions = {
					{
						topic = "some",
						qos = 0,
					},
				},
			}))
		)
		--[[
		82 						packet type == 8 (SUBSCRIBE), flags == 0x2 (fixed value)
		21 						length == 0x21 == 33 bytes
			0002 				variable header: Packet Identifier == 2
				0006 736F6D652F23 						topic filter #1 == string "some/#"
				00 										QoS #1
				000F 6F746865722F2B2F746F7069632F23 	topic filter #2 == string "other/+/topic/#"
				01 										QoS #2
				0001 23 								topic filter #3 == string "#"
				02 										QoS #3
		]]
		assert.are.equal(
			"822100020006736F6D652F2300000F6F746865722F2B2F746F7069632F230100012302",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 2,
				subscriptions = {
					{
						topic = "some/#",
						qos = 0,
					},
					{
						topic = "other/+/topic/#",
						qos = 1,
					},
					{
						topic = "#",
						qos = 2,
					},
				},
			}))
		)
		-- invalid calls:
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 0,
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 1,
				subscriptions = {},
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 1,
				subscriptions = {
					"invalid"
				},
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 1,
				subscriptions = {
					{}
				},
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 1,
				subscriptions = {
					{
						topic = false,
					}
				},
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 1,
				subscriptions = {
					{
						topic = "asdf",
						qos = 3,
					},
				},
			}
		end)
		assert.has.errors(function()
			protocol.make_packet{
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 1,
				subscriptions = {
					{
						topic = "asdf",
						qos = 0,
					},
					{}
				},
			}
		end)
	end)

	it("UNSUBSCRIBE", function()
		--[[
		A2 						packet type == 0xA == 10 (UNSUBSCRIBE), flags == 0x2 (fixed value)
		08 						length == 8 bytes
			0001 				variable header: Packet Identifier == 1
				0004 736F6D65 	topic filter #1 == string "some"
		]]
		assert.are.equal(
			"A20800010004736F6D65",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.UNSUBSCRIBE,
				packet_id = 1,
				subscriptions = {
					"some"
				},
			}))
		)
		--[[
		A2 						packet type == 0xA == 10 (UNSUBSCRIBE), flags == 0x2 (fixed value)
		1E 						length == 0x1E == 30 bytes
			1234 				variable header: Packet Identifier == 0x1234
				0006 736F6D652F23 						topic filter #1 == string "some/#"
				000F 6F746865722F2B2F746F7069632F23 	topic filter #1 == string "other/+/topic/#"
				0001 23 								topic filter #1 == string "#"
		]]
		assert.are.equal(
			"A21E12340006736F6D652F23000F6F746865722F2B2F746F7069632F23000123",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.UNSUBSCRIBE,
				packet_id = 0x1234,
				subscriptions = {
					"some/#",
					"other/+/topic/#",
					"#",
				},
			}))
		)
	end)

	it("PINGREQ", function()
		--[[
		C0 						packet type == 12 (PINGREQ), flags == 0
		00 						length == 0
		]]
		assert.are.equal(
			"C000",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.PINGREQ
			}))
		)
	end)

	it("DISCONNECT", function()
		--[[
		E0 						packet type == 14 (DISCONNECT), flags == 0
		00 						length == 0
		]]
		assert.are.equal(
			"E000",
			tools.hex(tostring(protocol.make_packet{
				type = protocol.packet_type.DISCONNECT
			}))
		)
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
