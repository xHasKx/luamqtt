-- busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/protocol5-parse.lua
-- DOC: https://docs.oasis-open.org/mqtt/mqtt/v5.0/cos02/mqtt-v5.0-cos02.html

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

local extract_hex = require("./tests/extract_hex")

describe("MQTT v5.0 protocol: parsing packets: generic", function()
	local protocol5 = require("mqtt.protocol5")

	it("failures", function()
		assert.is_false(protocol5.parse_packet(make_read_func_hex("")))
		assert.is_false(protocol5.parse_packet(make_read_func_hex("01")))
		assert.is_false(protocol5.parse_packet(make_read_func_hex("02")))
		assert.is_false(protocol5.parse_packet(make_read_func_hex("0304")))
		assert.is_false(protocol5.parse_packet(make_read_func_hex("20")))
		assert.is_false(protocol5.parse_packet(make_read_func_hex("20030000"))) -- CONNACK with invalid length
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: CONNACK", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("CONNACK with minimal params and without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				20 					-- packet type == 2 (CONNACK), flags == 0
				03 					-- variable length == 3 bytes
					00 				-- 0-th bit is sp (session present) -- DOC: 3.2.2.1 Connect Acknowledge Flags
					00 				-- connect reason code
					00				-- properties length
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.CONNACK, sp=false, rc=0, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("CONNACK with full params and without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				20 					-- packet type == 2 (CONNACK), flags == 0
				03 					-- variable length == 3 bytes
					01 				-- 0-th bit is sp (session present) -- DOC: 3.2.2.1 Connect Acknowledge Flags
					8A 				-- connect reason code
					00				-- properties length
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.CONNACK, sp=true, rc=0x8A, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("CONNACK with full params and full properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				20 					-- packet type == 2 (CONNACK), flags == 0
				75 					-- variable length == 0x66 == 102 bytes

					01 				-- 0-th bit is sp (session present) -- DOC: 3.2.2.1 Connect Acknowledge Flags
					82 				-- connect reason code

					72				-- properties length == 0x63 == 99 bytes

					11 00000E10		-- property 0x11 == 3600, -- DOC: 3.2.2.3.2 Session Expiry Interval
					21 1234			-- property 0x21 == 0x1234, -- DOC: 3.2.2.3.3 Receive Maximum
					24 01			-- property 0x24 == 1, -- DOC: 3.2.2.3.4 Maximum QoS
					25 01			-- property 0x25 == 1, -- DOC: 3.2.2.3.5 Retain Available
					27 00004567		-- property 0x27 == 0x4567, -- DOC: 3.2.2.3.6 Maximum Packet Size
					12 0005 736C617665	-- property 0x12 == "slave", -- DOC: 3.2.2.3.7 Assigned Client Identifier
					22 4321			-- property 0x22 == 0x4321, -- DOC: 3.2.2.3.8 Topic Alias Maximum
					1F 0007 70726F63656564	-- property 0x1F == "proceed", -- DOC: 3.2.2.3.9 Reason String
					28 01			-- property 0x28 == 1, -- DOC: 3.2.2.3.11 Wildcard Subscription Available
					29 00			-- property 0x29 == 0, -- DOC: 3.2.2.3.12 Subscription Identifiers Available
					2A 01			-- property 0x2A == 1, -- DOC: 3.2.2.3.13 Shared Subscription Available
					13 0078			-- property 0x13 == 120, -- DOC: 3.2.2.3.14 Server Keep Alive
					1A 0005 686572652F	-- property 0x1A == "here/", -- DOC: 3.2.2.3.15 Response Information
					1C 000D 736565202F6465762F6E756C6C	-- property 0x1C == "see /dev/null", -- DOC: 3.2.2.3.16 Server Reference
					15 0005 6775657373	-- property 0x15 == "guess", -- DOC: 3.2.2.3.17 Authentication Method
					16 0002 3130		-- property 0x16 == "10", -- DOC: 3.2.2.3.18 Authentication Data
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.2.2.3.10 User Property
					26 0005 68656C6C6F 0005 616761696E	-- property 0x26 (user) == ("hello", "again")  -- DOC: 3.2.2.3.10 User Property
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.CONNACK, sp=true, rc=0x82,
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
					hello = "again",
					{"hello", "world"},
					{"hello", "again"},
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: PUBLISH", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("PUBLISH with minimal params, without payload and without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				30 					-- packet type == 3 (PUBLISH), flags == 0, dup=0, qos=0, retain=0
				07 					-- variable length == 3 bytes

					0004 74657374	-- topic name == "test"
					00				-- properties length
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBLISH, dup=false, qos=0, retain=false, topic="test", properties={}, user_properties={},
			},
			packet
		)
	end)

	it("PUBLISH with minimal params, with payload and without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				39 					-- packet type == 3 (PUBLISH), flags == 0, dup=1, qos=0, retain=1
				0B 					-- variable length == 3 bytes

					0004 74657374	-- topic name == "test"
					00				-- properties length

					6B756B75		-- payload == "kuku"
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBLISH, dup=true, qos=0, retain=true, topic="test", payload="kuku", properties={}, user_properties={},
			},
			packet
		)
	end)

	it("PUBLISH with full params, with payload and without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				3D 					-- packet type == 3 (PUBLISH), flags == 0, dup=1, qos=2, retain=1
				0D 					-- variable length == 3 bytes

					0004 74657374	-- topic name == "test"
					1234			-- packet identifier == 0x1234
					00				-- properties length

					6B756B75		-- payload == "kuku"
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBLISH, dup=true, qos=2, packet_id=0x1234, retain=true, topic="test", payload="kuku", properties={}, user_properties={},
			},
			packet
		)
	end)

	it("PUBLISH with full params, with payload and full properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				3D 					-- packet type == 3 (PUBLISH), flags == 0, dup=1, qos=2, retain=1
				43 					-- variable length == 0x48 == 72 bytes

					0004 74657374	-- topic name == "test"
					1234			-- packet identifier == 0x1234
					36				-- properties length == 0x3B == 59 bytes

					01 01			-- property 0x01 == 1 -- DOC: 3.3.2.3.2 Payload Format Indicator
					02 0000012C		-- property 0x02 == 300 -- DOC: 3.3.2.3.3 Message Expiry Interval
					23 0002			-- property 0x23 == 2 -- DOC: 3.3.2.3.4 Topic Alias
					08 0007 6865792F707562	-- property 0x08 == "hey/pub" -- DOC: 3.3.2.3.5 Response Topic
					09 0002 3230	-- property 0x09 == "20" -- DOC: 3.3.2.3.6 Correlation Data
					0B 02			-- property 0x0B == 2 -- DOC: 3.3.2.3.8 Subscription Identifier
					03 0009 696D6167652F706E67	-- property 0x03 == "image/png" -- DOC: 3.3.2.3.9 Content Type
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.2.2.3.10 User Property

					6B756B75		-- payload == "kuku"
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBLISH, dup=true, qos=2, packet_id=0x1234, retain=true, topic="test", payload="kuku",
				properties={
					payload_format_indicator = 1,
					message_expiry_interval = 300,
					topic_alias = 2,
					response_topic = "hey/pub",
					correlation_data = "20",
					subscription_identifiers = {2}, -- , 3, 2048
					content_type = "image/png",
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)

	it("PUBLISH with full params, with payload and several subscription identifiers in properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				3D 					-- packet type == 3 (PUBLISH), flags == 0, dup=1, qos=2, retain=1
				14 					-- variable length == 0x48 == 72 bytes

					0004 74657374	-- topic name == "test"
					1234			-- packet identifier == 0x1234
					07				-- properties length == 0x3B == 59 bytes

					0B 02			-- property 0x0B == 2 -- DOC: 3.3.2.3.8 Subscription Identifier
					0B 03			-- property 0x0B == 3 -- DOC: 3.3.2.3.8 Subscription Identifier
					0B 8010			-- property 0x0B == 0x8001 as variable length field == 2048 -- DOC: 3.3.2.3.8 Subscription Identifier

					6B756B75		-- payload == "kuku"
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBLISH, dup=true, qos=2, packet_id=0x1234, retain=true, topic="test", payload="kuku",
				properties={
					subscription_identifiers = {2, 3, 2048}
				},
				user_properties={
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: PUBACK", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("with minimal params, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				40 					-- packet type == 4 (PUBACK), flags == 0
				02 					-- variable length == 2 bytes

					0001				-- packet_id to acknowledge
										-- no reason code and properties
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBACK, rc=0, packet_id=1, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				40 					-- packet type == 4 (PUBACK), flags == 0
				04 					-- variable length == 4 bytes

					1234				-- packet_id to acknowledge
					10					-- reason code: 0x10 (No matching subscribers)
					00					-- properties length == 0
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBACK, rc=0x10, packet_id=0x1234, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, with properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				40 					-- packet type == 4 (PUBACK), flags == 0
				1F 					-- variable length == 31 bytes

					F00F				-- packet_id to acknowledge
					97					-- reason code: 0x97 (Quota exceeded)
					1B					-- properties length == 27 bytes

					1F 0009 69742773206F6B6179			-- property 0x1F == "it's okay" -- DOC: 3.4.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.4.2.2.3 User Property
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBACK, rc=0x97, packet_id=0xF00F,
				properties={
					reason_string = "it's okay",
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: PUBREC", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("with minimal params, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				50 					-- packet type == 5 (PUBREC), flags == 0

				02 					-- variable length == 2 bytes

					0002				-- packet_id to acknowledge
										-- no reason code and properties
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBREC, rc=0, packet_id=2, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				50 					-- packet type == 5 (PUBREC), flags == 0

				04 					-- variable length == 4 bytes

					1234				-- packet_id to acknowledge
					80					-- reason code: 0x80 (Unspecified error)
					00					-- properties length == 0
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBREC, rc=0x80, packet_id=0x1234, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, with properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				50 					-- packet type == 5 (PUBREC), flags == 0
				1F 					-- variable length == 31 bytes

					F00F				-- packet_id to acknowledge
					83					-- reason code: 0x83 (Implementation specific error)
					1B					-- properties length == 27 bytes

					1F 0009 69742773206F6B6179			-- property 0x1F == "it's okay" -- DOC: 3.5.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.4.2.2.3 User Property
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBREC, rc=0x83, packet_id=0xF00F,
				properties={
					reason_string = "it's okay",
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: PUBREL", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("with minimal params, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				62 					-- packet type == 6 (PUBREL), flags == 0x2
				02 					-- variable length == 2 bytes

					0003				-- packet_id to acknowledge
										-- no reason code and properties
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBREL, rc=0, packet_id=3, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				62 					-- packet type == 6 (PUBREL), flags == 0x2
				04 					-- variable length == 4 bytes

					1234				-- packet_id to acknowledge
					92					-- reason code: 0x92 (Packet Identifier not found)
					00					-- properties length == 0
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBREL, rc=0x92, packet_id=0x1234, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, with properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				62 					-- packet type == 6 (PUBREL), flags == 0x2
				1F 					-- variable length == 31 bytes

					F00F				-- packet_id to acknowledge
					00					-- reason code: 0x00 (Success)
					1B					-- properties length == 27 bytes

					1F 0009 69742773206F6B6179			-- property 0x1F == "it's okay" -- DOC: 3.6.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.4.2.2.3 User Property
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBREL, rc=0x00, packet_id=0xF00F,
				properties={
					reason_string = "it's okay",
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: PUBCOMP", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("with minimal params, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				70 					-- packet type == 7 (PUBCOMP), flags == 0
				02 					-- variable length == 2 bytes

					0004				-- packet_id to acknowledge
										-- no reason code and properties
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBCOMP, rc=0, packet_id=4, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				70 					-- packet type == 7 (PUBCOMP), flags == 0
				04 					-- variable length == 4 bytes

					1234				-- packet_id to acknowledge
					92					-- reason code: 0x92 (Packet Identifier not found)
					00					-- properties length == 0
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBCOMP, rc=0x92, packet_id=0x1234, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, with properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				70 					-- packet type == 7 (PUBCOMP), flags == 0
				1F 					-- variable length == 31 bytes

					F00F				-- packet_id to acknowledge
					00					-- reason code: 0x00 (Success)
					1B					-- properties length == 27 bytes

					1F 0009 69742773206F6B6179			-- property 0x1F == "it's okay" -- DOC: 3.7.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.4.2.2.3 User Property
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PUBCOMP, rc=0x00, packet_id=0xF00F,
				properties={
					reason_string = "it's okay",
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: SUBACK", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("one subscription, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				90 					-- packet type == 9 (SUBACK), flags == 0
				04 					-- variable length == 4 bytes

					0101				-- packet_id of SUBSCRIBE that is acknowledged
					00					-- properties length

					00					-- Subscribe Reason Codes, 0x00 == Granted QoS 0
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.SUBACK, packet_id=0x0101, rc={0}, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("several subscriptions, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				90 					-- packet type == 9 (SUBACK), flags == 0
				07 					-- variable length == 7 bytes

					0101				-- packet_id of SUBSCRIBE that is acknowledged
					00					-- properties length

					00					-- Subscribe Reason Codes, 0x00 == Granted QoS 0
					01					-- Subscribe Reason Codes, 0x01 == Granted QoS 1
					80					-- Subscribe Reason Codes, 0x80 == Unspecified error
					97					-- Subscribe Reason Codes, 0x97 == Quota exceeded
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.SUBACK, packet_id=0x0101, rc={0, 1, 0x80, 0x97}, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("several subscriptions, with properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				90 					-- packet type == 9 (SUBACK), flags == 0
				22 					-- variable length == 34 bytes

					0101				-- packet_id of SUBSCRIBE that is acknowledged
					1B					-- properties length == 27 bytes

					1F 0009 69742773206F6B6179			-- property 0x1F == "it's okay" -- DOC: 3.7.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.4.2.2.3 User Property

					00					-- Subscribe Reason Codes, 0x00 == Granted QoS 0
					01					-- Subscribe Reason Codes, 0x01 == Granted QoS 1
					80					-- Subscribe Reason Codes, 0x80 == Unspecified error
					97					-- Subscribe Reason Codes, 0x97 == Quota exceeded
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.SUBACK, packet_id=0x0101, rc={0, 1, 0x80, 0x97},
				properties={
					reason_string = "it's okay",
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: UNSUBACK", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("one subscription, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				B0 					-- packet type == 11 (UNSUBACK), flags == 0
				04 					-- variable length == 4 bytes

					0202				-- packet_id of UNSUBSCRIBE that is acknowledged
					00					-- properties length

					00					-- Unsubscribe Reason Codes, 0x00 == Success
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.UNSUBACK, packet_id=0x0202, rc={0}, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("several subscriptions, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				B0 					-- packet type == 11 (UNSUBACK), flags == 0
				07 					-- variable length == 7 bytes

					2323				-- packet_id of UNSUBSCRIBE that is acknowledged
					00					-- properties length

					00					-- Unsubscribe Reason Codes, 0x00 == Success
					11					-- Unsubscribe Reason Codes, 0x11 == No subscription existed
					80					-- Unsubscribe Reason Codes, 0x80 == Unspecified error
					87					-- Unsubscribe Reason Codes, 0x87 == Not authorized
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.UNSUBACK, packet_id=0x2323, rc={0, 0x11, 0x80, 0x87}, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("several subscriptions, with properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				B0 					-- packet type == 11 (UNSUBACK), flags == 0
				22 					-- variable length == 34 bytes

					3434				-- packet_id of UNSUBSCRIBE that is acknowledged
					1B					-- properties length == 27 bytes

					1F 0009 69742773206F6B6179			-- property 0x1F == "it's okay" -- DOC: 3.7.2.2.2 Reason String
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.4.2.2.3 User Property

					00					-- Unsubscribe Reason Codes, 0x00 == Success
					11					-- Unsubscribe Reason Codes, 0x11 == No subscription existed
					80					-- Unsubscribe Reason Codes, 0x80 == Unspecified error
					87					-- Unsubscribe Reason Codes, 0x87 == Not authorized
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.UNSUBACK, packet_id=0x3434, rc={0, 0x11, 0x80, 0x87},
				properties={
					reason_string = "it's okay",
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: PINGRESP", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("the only variant", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				D0 					-- packet type == 13 (PINGRESP), flags == 0
				00 					-- variable length == 0 bytes
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PINGRESP, properties={}, user_properties={},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: DISCONNECT", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("minimal", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				E0 					-- packet type == 14 (DISCONNECT), flags == 0
				00 					-- variable length == 0 bytes
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.DISCONNECT, rc=0, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				E0 					-- packet type == 14 (DISCONNECT), flags == 0
				02 					-- variable length == 2 bytes

					00					-- reason code == 0, DOC: 3.14.2.1 Disconnect Reason Code
					00					-- properties length == 0

			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.DISCONNECT, rc=0, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				E0 					-- packet type == 14 (DISCONNECT), flags == 0
				02 					-- variable length == 2 bytes

					81					-- reason code == 0x81 (Malformed Packet), DOC: 3.14.2.1 Disconnect Reason Code
					00					-- properties length == 0
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.DISCONNECT, rc=0x81, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, with properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				E0 					-- packet type == 14 (DISCONNECT), flags == 0
				38 					-- variable length == 56 bytes

					81					-- reason code == 0x81 (Malformed Packet), DOC: 3.14.2.1 Disconnect Reason Code
					36					-- properties length == 54 bytes

					11 00000E10							-- property 0x11 == 3600, -- DOC: 3.14.2.2.2 Session Expiry Interval
					1F 0009 69742773206F6B6179			-- property 0x1F == "it's okay" -- DOC: 3.14.2.2.3 Reason String
					1C 0013 6D6567612D62726F6B65722076313030353030	-- property 1C == "mega-broker v100500" -- DOC: 3.14.2.2.5 Server Reference
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.14.2.2.4 User Property
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.DISCONNECT, rc=0x81,
				properties={
					reason_string = "it's okay",
					server_reference = "mega-broker v100500",
					session_expiry_interval = 3600,
				},
				user_properties={
					hello = "world",
				},
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: AUTH", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")

	it("minimal", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				F0 					-- packet type == 15 (AUTH), flags == 0
				00 					-- variable length == 0 bytes
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.AUTH, rc=0, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				F0 					-- packet type == 15 (AUTH), flags == 0
				02 					-- variable length == 2 bytes

					00					-- reason code == 0x00 (Success), DOC: 3.15.2.1 Authenticate Reason Code
					00					-- properties length == 0 bytes
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.AUTH, rc=0, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				F0 					-- packet type == 15 (AUTH), flags == 0
				02 					-- variable length == 2 bytes

					18					-- reason code == 0x18 (Continue authentication), DOC: 3.15.2.1 Authenticate Reason Code
					00					-- properties length == 0 bytes
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.AUTH, rc=0x18, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("with non-zero reason code, with properties with same name", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				F0 					-- packet type == 15 (AUTH), flags == 0
				44 					-- variable length == 68 bytes

					18					-- reason code == 0x18 (Continue authentication), DOC: 3.15.2.1 Authenticate Reason Code
					42					-- properties length == 66 bytes

					15 0006 6D6574686F64 					-- property 0x15 == "method", -- DOC: 3.15.2.2.2 Authentication Method
					16 000B 6B6E6F636B2D6B6E6F636B			-- property 0x16 == "knock-knock", -- DOC: 3.15.2.2.3 Authentication Data
					1F 0009 69742773206F6B6179				-- property 0x1F == "it's okay" -- DOC: 3.15.2.2.4 Reason String
					26 0005 68656C6C6F 0005 776F726C64		-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.15.2.2.5 User Property
					26 0005 68656C6C6F 0006 776F726C6432	-- property 0x26 (user) == ("hello", "world2")  -- DOC: 3.15.2.2.5 User Property
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.AUTH, rc=0x18,
				properties={
					authentication_data = "knock-knock",
					authentication_method = "method",
					reason_string = "it's okay",
				},
				user_properties={
					{"hello", "world"},
					{"hello", "world2"},
					hello = "world2",
				},
			},
			packet
		)
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
