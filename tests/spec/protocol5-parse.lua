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

describe("MQTT v5.0 protocol: parsing packets: CONNECT[1]", function()
	local mqtt = require("mqtt")
	local protocol = require("mqtt.protocol")
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

	it("minimal properties", function()
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v50, clean = false, keep_alive = 0, id = "",
				properties = {}, user_properties = {},
			},
			protocol5.parse_packet(make_read_func_hex(
				extract_hex[[
					10 										-- packet type == 1 (CONNECT), flags == 0 (reserved)
					0D 										-- variable length == 13 bytes
						0004 4D515454						-- protocol name length (4 bytes) and "MQTT" string
						05									-- protocol version: 5 (v5.0)
						00									-- connect flags
						0000								-- keep alive == 0
						00									-- properties length (0 bytes)
						0000								-- client id length (0 bytes) and its string content (empty)
				]]
			))
		)
	end)

	it("connect flags: clean=true", function()
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v50, clean = true, keep_alive = 0, id = "",
				properties = {}, user_properties = {},
			},
			protocol5.parse_packet(make_read_func_hex(
				extract_hex[[
					10 										-- packet type == 1 (CONNECT), flags == 0 (reserved)
					0D 										-- variable length == 13 bytes
						0004 4D515454						-- protocol name length (4 bytes) and "MQTT" string
						05									-- protocol version: 5 (v5.0)
						02									-- connect flags: clean=true
						0000								-- keep alive == 0
						00									-- properties length (0 bytes)
						0000								-- client id length (0 bytes) and its string content (empty)
				]]
			))
		)
	end)

	it("connect flags: clean=false, will=true, no props", function()
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v50, clean = false, keep_alive = 0, id = "",
				properties = {}, user_properties = {},
				will = {
					qos = 0, retain = false,
					topic = "bye", payload = "bye",
					properties = {}, user_properties = {},
				}
			},
			protocol5.parse_packet(make_read_func_hex(
				extract_hex[[
					10 										-- packet type == 1 (CONNECT), flags == 0 (reserved)
					18 										-- variable length == 24 bytes
						0004 4D515454						-- protocol name length (4 bytes) and "MQTT" string
						05									-- protocol version: 5 (v5.0)
						04									-- connect flags: clean=false, will=true
						0000								-- keep alive == 0
						00									-- properties length (0 bytes)
						0000								-- client id length (0 bytes) and its string content (empty)
						00									-- will message properties length (0 bytes)
						0003 627965							-- will message topic: 3 bytes length and string "bye"
						0003 627965							-- will message payload: 3 bytes length and bytes of string "bye"
				]]
			))
		)
	end)

	it("connect flags: clean=false, will=true, will qos=2, will retain=true, and full will properties", function()
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v50, clean = false, keep_alive = 0, id = "",
				properties = {}, user_properties = {},
				will = {
					qos = 2, retain = true,
					topic = "bye", payload = "bye",
					properties = {
						content_type = "text/plain", correlation_data = "1234", message_expiry_interval = 10,
						payload_format_indicator = 1, response_topic = "resp", will_delay_interval = 30,
					}, user_properties = {
						{"hello", "world"}, {"hello", "again"},
						a = "b", hello = "again",
					},
				}
			},
			protocol5.parse_packet(make_read_func_hex(
				extract_hex[[
					10 										-- packet type == 1 (CONNECT), flags == 0 (reserved)
					64 										-- variable length == 100 bytes
						0004 4D515454						-- protocol name length (4 bytes) and "MQTT" string
						05									-- protocol version: 5 (v5.0)
						34									-- connect flags: clean=false, will=true, will qos=2, will retain=true
						0000								-- keep alive == 0
						00									-- properties length (0 bytes)
						0000								-- client id length (0 bytes) and its string content (empty)

						4C									-- properties length (76 bytes)
						18 0000001E							-- property 0x18 == 30				-- DOC: 3.1.3.2.2 Will Delay Interval
						01 01								-- property 0x01 == 1				-- DOC: 3.1.3.2.3 Payload Format Indicator
						02 0000000A							-- property 0x02 == 10				-- DOC: 3.1.3.2.4 Message Expiry Interval
						03 000A 746578742F706C61696E		-- property 0x03 == "text/plain"	-- DOC: 3.1.3.2.5 Content Type
						08 0004 72657370					-- property 0x08 == "resp"			-- DOC: 3.1.3.2.6 Response Topic
						09 0004 31323334					-- property 0x09 == "1234"			-- DOC: 3.1.3.2.7 Correlation Data
						26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")	-- DOC: 3.1.3.2.8 User Property
						26 0005 68656C6C6F 0005 616761696E	-- property 0x26 (user) == ("hello", "again")	-- DOC: 3.1.3.2.8 User Property
						26 0001 61 0001 62					-- property 0x26 (user) == ("a", "b")			-- DOC: 3.1.3.2.8 User Property

						0003 627965							-- will message topic: 3 bytes length and string "bye"
						0003 627965							-- will message payload: 3 bytes length and bytes of string "bye"
				]]
			))
		)
	end)

	it("connect flags: password=true, keep_alive=30", function()
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v50, clean = false, keep_alive = 30, id = "",
				password = "secret",
				properties = {}, user_properties = {},
			},
			protocol5.parse_packet(make_read_func_hex(
				extract_hex[[
					10 										-- packet type == 1 (CONNECT), flags == 0 (reserved)
					15 										-- variable length == 21 bytes
						0004 4D515454						-- protocol name length (4 bytes) and "MQTT" string
						05									-- protocol version: 5 (v5.0)
						40									-- connect flags: password=true
						001E								-- keep alive == 30
						00									-- properties length (0 bytes)
						0000								-- client id length (0 bytes) and its string content (empty)
						0006 736563726574					-- password length (6 bytes) and its string content - "secret"
				]]
			))
		)
	end)

	it("connect flags: username=true", function()
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v50, clean = false, keep_alive = 0, id = "",
				username = "user",
				properties = {}, user_properties = {},
			},
			protocol5.parse_packet(make_read_func_hex(
				extract_hex[[
					10 										-- packet type == 1 (CONNECT), flags == 0 (reserved)
					13 										-- variable length == 19 bytes
						0004 4D515454						-- protocol name length (4 bytes) and "MQTT" string
						05									-- protocol version: 5 (v5.0)
						80									-- connect flags: username=true
						0000								-- keep alive == 0
						00									-- properties length (0 bytes)
						0000								-- client id length (0 bytes) and its string content (empty)
						0004 75736572						-- username length (4 bytes) and its string content - "user"
				]]
			))
		)
	end)

	it("connect flags: username=true, password=true", function()
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v50, clean = false, keep_alive = 0, id = "",
				username = "user", password = "secret",
				properties = {}, user_properties = {},
			},
			protocol5.parse_packet(make_read_func_hex(
				extract_hex[[
					10 										-- packet type == 1 (CONNECT), flags == 0 (reserved)
					1B 										-- variable length == 27 bytes
						0004 4D515454						-- protocol name length (4 bytes) and "MQTT" string
						05									-- protocol version: 5 (v5.0)
						C0									-- connect flags: username=true, password=true
						0000								-- keep alive == 0
						00									-- properties length (0 bytes)
						0000								-- client id length (0 bytes) and its string content (empty)
						0004 75736572						-- username length (4 bytes) and its string content - "user"
						0006 736563726574					-- password length (6 bytes) and its string content - "secret"
				]]
			))
		)
	end)

end)

describe("MQTT v5.0 protocol: parsing packets: CONNACK[2]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

	it("CONNACK with invalid flags", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				21 					-- packet type == 2 (CONNACK), flags == 0x1
				03 					-- variable length == 3 bytes
					00 				-- 0-th bit is sp (session present) -- DOC: 3.2.2.1 Connect Acknowledge Flags
					00 				-- connect reason code
					00				-- properties length
			]]
		))
		assert.are.same(packet, false)
		assert.are.same(err, "CONNACK: unexpected flags value: 1")
	end)

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

					72				-- properties length == 0x72 == 114 bytes

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

describe("MQTT v5.0 protocol: parsing packets: PUBLISH[3]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: PUBACK[4]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: PUBREC[5]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: PUBREL[6]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

	it("with minimal params, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				62 					-- packet type == 6 (PUBREL), flags == 0x2
				02 					-- variable length == 2 bytes

					0003				-- packet_id to acknowledge
										-- no reason code and no properties
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

describe("MQTT v5.0 protocol: parsing packets: PUBCOMP[7]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: SUBSCRIBE[8]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

	it("with invalid empty subscription list", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				82 					-- packet type == 8 (SUBSCRIBE), flags == 0x2
				03 					-- variable length == 3 bytes

					0005			-- packet_id
					00				-- properties length == 0
			]]
		))
		assert.are.same(false, packet)
		assert.are.same("SUBSCRIBE: empty subscriptions list", err)
	end)

	it("with minimal params, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				82 					-- packet type == 8 (SUBSCRIBE), flags == 0x2
				0A 					-- variable length == 10 bytes

					0005			-- packet_id
					00				-- properties length == 0

					0004 74657374	-- topic name == "test"
					00				-- Subscription Options == 0
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.SUBSCRIBE, packet_id=5, properties={}, user_properties={},
				subscriptions = {
					{
						topic = "test",
						no_local = false,
						qos = 0,
						retain_as_published = false,
						retain_handling = 0,
					},
				},
			},
			packet
		)
	end)

	it("with properties and several subscriptions", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				82 					-- packet type == 8 (SUBSCRIBE), flags == 0x2
				3C 					-- variable length == 60 bytes

					0005			-- packet_id
					11				-- properties length == 17

					0B 01			-- property 0x0B == 1 -- DOC: 3.3.2.3.8 Subscription Identifier
					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.2.2.3.10 User Property

					0005 7465737431	-- topic name == "test1"
					00				-- Subscription Options == 0
					0005 7465737432	-- topic name == "test2"
					01				-- Subscription Options == 1 (qos=1)
					0005 7465737433	-- topic name == "test3"
					06				-- Subscription Options == 6 (qos=2, no_local=true)
					0005 7465737434	-- topic name == "test4"
					0A				-- Subscription Options == 12 (qos=2, retain_as_published=true)
					0005 7465737435	-- topic name == "test5"
					1E				-- Subscription Options == 30 (qos=2, no_local=true, retain_as_published=true, retain_handling=1)
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.SUBSCRIBE, packet_id=5,
				properties={
					subscription_identifiers = 1,
				},
				user_properties={
					hello = "world",
				},
				subscriptions = {
					{
						topic = "test1",
						no_local = false,
						qos = 0,
						retain_as_published = false,
						retain_handling = 0,
					},
					{
						topic = "test2",
						no_local = false,
						qos = 1,
						retain_as_published = false,
						retain_handling = 0,
					},
					{
						topic = "test3",
						no_local = true,
						qos = 2,
						retain_as_published = false,
						retain_handling = 0,
					},
					{
						topic = "test4",
						no_local = false,
						qos = 2,
						retain_as_published = true,
						retain_handling = 0,
					},
					{
						topic = "test5",
						no_local = true,
						qos = 2,
						retain_as_published = true,
						retain_handling = 1,
					},
				},
			},
			packet
		)
	end)

	it("with invalid properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				82 					-- packet type == 8 (SUBSCRIBE), flags == 0x2
				0E 					-- variable length == 14 bytes

					0005			-- packet_id
					04				-- properties length == 0

					0B 01			-- property 0x0B == 1 -- DOC: 3.3.2.3.8 Subscription Identifier
					0B 02			-- property 0x0B == 2 -- DOC: 3.3.2.3.8 Subscription Identifier (It is a Protocol Error to include the Subscription Identifier more than once)

					0004 74657374	-- topic name == "test"
					00				-- Subscription Options == 0
			]]
		))
		assert.are.same(false, packet)
		assert.are.same('SUBSCRIBE: failed to parse packet properties: it is a Protocol Error to include the subscription_identifiers (11) property more than once', err)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: SUBACK[9]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: UNSUBSCRIBE[10]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

	it("without subscriptions", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				A2 					-- packet type == 10 (UNSUBSCRIBE), flags == 0x2
				03 					-- variable length == 3 bytes

					0001			-- packet_id
					00				-- properties length == 0
			]]
		))
		assert.are.same(false, packet)
		assert.are.same("UNSUBSCRIBE: empty subscriptions list", err)
	end)

	it("with minimal params, without properties", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				A2 					-- packet type == 10 (UNSUBSCRIBE), flags == 0x2
				09 					-- variable length == 9 bytes

					0002			-- packet_id
					00				-- properties length == 0

					0004 74657374	-- topic name == "test"
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.UNSUBSCRIBE, packet_id=2, properties={}, user_properties={},
				subscriptions = { "test" },
			},
			packet
		)
	end)

	it("with invalid property", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				A2 					-- packet type == 10 (UNSUBSCRIBE), flags == 0x2
				0C 					-- variable length == 12 bytes

					0001			-- packet_id
					02				-- properties length == 2

					0B 01			-- property 0x0B == 1 -- DOC: 3.3.2.3.8 Subscription Identifier

					0005 7465737431	-- topic name == "test1"
			]]
		))
		assert.are.same(false, packet)
		assert.are.same("UNSUBSCRIBE: failed to parse packet properties: property subscription_identifiers (11) is not allowed for that packet type", err)
	end)

	it("with properties and sever lsubscriptions", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				A2 					-- packet type == 10 (UNSUBSCRIBE), flags == 0x2
				27 					-- variable length == 39 bytes

					0003			-- packet_id
					0F				-- properties length == 15

					26 0005 68656C6C6F 0005 776F726C64	-- property 0x26 (user) == ("hello", "world")  -- DOC: 3.2.2.3.10 User Property

					0005 7465737431	-- topic name == "test1"
					0005 7465737432	-- topic name == "test2"
					0005 7465737433	-- topic name == "test3"
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.UNSUBSCRIBE, packet_id=3, properties={}, user_properties={ hello="world" },
				subscriptions = { 'test1', 'test2', 'test3' },
			},
			packet
		)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: UNSUBACK[11]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: PINGREQ[12]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

	it("the only variant", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				C0 					-- packet type == 12 (PINGREQ), flags == 0
				00 					-- variable length == 0 bytes
			]]
		))
		assert.is_nil(err)
		assert.are.same(
			{
				type=pt.PINGREQ, properties={}, user_properties={},
			},
			packet
		)
	end)

	it("invalid extra data in the packet", function()
		local packet, err = protocol5.parse_packet(make_read_func_hex(
			extract_hex[[
				C0 					-- packet type == 12 (PINGREQ), flags == 0
				01 					-- variable length == 0 bytes

				00					-- invalid extra data
			]]
		))
		assert.are.same("PINGREQ: extra data in remaining length left after packet parsing", err)
		assert.are.same(false, packet)
	end)
end)

describe("MQTT v5.0 protocol: parsing packets: PINGRESP[13]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: DISCONNECT[14]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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

describe("MQTT v5.0 protocol: parsing packets: AUTH[15]", function()
	local protocol = require("mqtt.protocol")
	local pt = assert(protocol.packet_type)
	local protocol5 = require("mqtt.protocol5")
	local extract_hex = require("mqtt.tools").extract_hex

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
