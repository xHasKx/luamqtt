-- busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/protocol4-parse.lua
-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

describe("MQTT v3.1.1 protocol: parsing packets", function()
	local mqtt = require("mqtt")
	local protocol = require("mqtt.protocol")
	local protocol4 = require("mqtt.protocol4")
	local extract_hex = require("mqtt.tools").extract_hex

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

	it("failures", function()
		assert.is_false(protocol4.parse_packet(make_read_func_hex("")))
		assert.is_false(protocol4.parse_packet(make_read_func_hex("01")))
		assert.is_false(protocol4.parse_packet(make_read_func_hex("02")))
		assert.is_false(protocol4.parse_packet(make_read_func_hex("0304")))
		assert.is_false(protocol4.parse_packet(make_read_func_hex("20")))
		assert.is_false(protocol4.parse_packet(make_read_func_hex("20030000"))) -- CONNACK with invalid length
	end)

	it("CONNECT", function()
		assert.is_false(protocol4.parse_packet(make_read_func_hex("")))
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v311, clean = false, keep_alive = 0, id = "",
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					10 							-- packet type == 1 (CONNECT), flags == 0 (reserved)
					0C 							-- variable length == 12 bytes
						0004 4D515454			-- protocol name length (4 bytes) and "MQTT" string
						04						-- protocol version: 4 (v3.1.1)
						00						-- connect flags
						0000					-- keep alive == 0
						0000					-- client id length (0 bytes) and its string content (empty)
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v311, clean = true, keep_alive = 30, id = "",
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					10 							-- packet type == 1 (CONNECT), flags == 0 (reserved)
					0C 							-- variable length == 12 bytes
						0004 4D515454			-- protocol name length (4 bytes) and "MQTT" string
						04						-- protocol version: 4 (v3.1.1)
						02						-- connect flags: clean=true
						001E					-- keep alive == 30
						0000					-- client id length (0 bytes) and its string content (empty)
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v311, clean = false, keep_alive = 30, id = "test",
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					10 							-- packet type == 1 (CONNECT), flags == 0 (reserved)
					10 							-- variable length == 16 bytes
						0004 4D515454			-- protocol name length (4 bytes) and "MQTT" string
						04						-- protocol version: 4 (v3.1.1)
						00						-- connect flags
						001E					-- keep alive == 30
						0004 74657374			-- client id length (4 bytes) and its string content - "test"
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v311, clean = false, keep_alive = 30, id = "",
				will = { topic = "bye", payload = "bye", retain = false, qos = 0, },
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					10 							-- packet type == 1 (CONNECT), flags == 0 (reserved)
					16 							-- variable length == 22 bytes
						0004 4D515454			-- protocol name length (4 bytes) and "MQTT" string
						04						-- protocol version: 4 (v3.1.1)
						04						-- connect flags: clean=false, will=true
						001E					-- keep alive == 30
						0000					-- client id length (0 bytes) and its string content (empty)
						0003 627965				-- will topic: length (3 bytes) and "bye" string
						0003 627965				-- will message: length (3 bytes) and "bye" string
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v311, clean = false, keep_alive = 30, id = "",
				will = { topic = "bye", payload = "", retain = true, qos = 2, },
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					10 							-- packet type == 1 (CONNECT), flags == 0 (reserved)
					13 							-- variable length == 19 bytes
						0004 4D515454			-- protocol name length (4 bytes) and "MQTT" string
						04						-- protocol version: 4 (v3.1.1)
						34						-- connect flags: clean=false, will=true, will.qos=2, will.retain=true
						001E					-- keep alive == 30
						0000					-- client id length (0 bytes) and its string content (empty)
						0003 627965				-- will topic: length (3 bytes) and "bye" string
						0000					-- will message: length (0 bytes) and empty string
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v311, clean = false, keep_alive = 30, id = "", username = "user",
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					10 							-- packet type == 1 (CONNECT), flags == 0 (reserved)
					12 							-- variable length == 18 bytes
						0004 4D515454			-- protocol name length (4 bytes) and "MQTT" string
						04						-- protocol version: 4 (v3.1.1)
						80						-- connect flags: clean=false, will=false, password=false, username=true
						001E					-- keep alive == 30
						0000					-- client id length (0 bytes) and its string content (empty)
						0004 75736572			-- username length (4 bytes) and "user" string
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.CONNECT,
				version = mqtt.v311, clean = false, keep_alive = 30, id = "", username = "user", password = "1234",
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					10 							-- packet type == 1 (CONNECT), flags == 0 (reserved)
					18 							-- variable length == 24 bytes
						0004 4D515454			-- protocol name length (4 bytes) and "MQTT" string
						04						-- protocol version: 4 (v3.1.1)
						C0						-- connect flags: clean=false, will=false, password=true, username=true
						001E					-- keep alive == 30
						0000					-- client id length (0 bytes) and its string content (empty)
						0004 75736572			-- username length (4 bytes) and "user" string
						0004 31323334			-- password length (4 bytes) and "1234" payload
				]]
			))
		)
	end)

	it("CONNACK", function()
		assert.is_false(protocol4.parse_packet(make_read_func_hex("")))
		assert.are.same(
			{
				type=protocol.packet_type.CONNACK, sp=false, rc=0
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					20 					-- packet type == 2 (CONNACK), flags == 0
					02 					-- variable length == 2 bytes
						00 				-- 0-th bit is sp (session present) -- DOC: 3.2.2.2 Session Present
						00 				-- CONNACK return code
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.CONNACK, sp=true, rc=0
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex("20 02 0100")
			))
		)
		local packet = protocol4.parse_packet(make_read_func_hex(
			extract_hex("20 02 0001")
		))
		assert.are.same(
			{
				type=protocol.packet_type.CONNACK, sp=false, rc=1
			},
			packet
		)
		assert.are.same("Connection Refused, unacceptable protocol version", packet:reason_string())
		local packet = protocol4.parse_packet(make_read_func_hex(
			extract_hex("20 02 0020")
		))
		assert.are.same(
			{
				type=protocol.packet_type.CONNACK, sp=false, rc=32
			},
			packet
		)
		assert.are.same("Unknown: 32", packet:reason_string())
	end)

	it("PUBLISH", function()
		assert.are.same(
			{
				type = protocol.packet_type.PUBLISH,
				dup = true,
				qos = 1,
				retain = true,
				packet_id = 1,
				topic = "some",
				payload = "qos == 1, ok!",
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					3B 					-- packet type == 3 (PUBLISH), flags == 0xB == 1011 (dup=true, qos=1, retain=true)
					15 					-- variable length == 0x15 == 21 bytes
						0004 736F6D65 		-- topic "some"
						0001 				-- packet id of PUBLISH packet
							716F73203D3D20312C206F6B21 		-- payload to publish: "qos == 1, ok!"
				]]
			))
		)
		assert.are.same(
			{
				type = protocol.packet_type.PUBLISH,
				dup = false,
				qos = 0,
				retain = false,
				topic = "some",
				payload = "qos == 1, ok!",
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					30 					-- packet type == 3 (PUBLISH), flags == 0 == 0000 (dup=false, qos=0, retain=false)
					13 					-- variable length == 0x13 == 19 bytes
						0004 736F6D65 		-- topic "some"
							716F73203D3D20312C206F6B21 		-- payload to publish: "qos == 1, ok!"
				]]
			))
		)
	end)

	it("PUBACK", function()
		assert.are.same(
			{
				type=protocol.packet_type.PUBACK, packet_id=1
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					40 					-- packet type == 4 (PUBACK), flags == 0
					02 					-- variable length == 2 bytes
						0001 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.PUBACK, packet_id=0x7FF7
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					40 					-- packet type == 4 (PUBACK), flags == 0
					02 					-- variable length == 2 bytes
						7FF7 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
	end)

	it("PUBREC", function()
		assert.are.same(
			{
				type=protocol.packet_type.PUBREC, packet_id=1
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					50 					-- packet type == 5 (PUBREC), flags == 0
					02 					-- variable length == 2 bytes
						0001 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.PUBREC, packet_id=0x4567
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					50 					-- packet type == 5 (PUBREC), flags == 0
					02 					-- variable length == 2 bytes
						4567 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
	end)

	it("PUBREL", function()
		assert.are.same(
			{
				type=protocol.packet_type.PUBREL, packet_id=1
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					62 					-- packet type == 6 (PUBREL), flags == 2 (reserved bits: 0010)
					02 					-- variable length == 2 bytes
						0001 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.PUBREL, packet_id=0x1234
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					62 					-- packet type == 6 (PUBREL), flags == 2 (reserved bits: 0010)
					02 					-- variable length == 2 bytes
						1234 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
	end)

	it("PUBCOMP", function()
		assert.are.same(
			{
				type=protocol.packet_type.PUBCOMP, packet_id=1
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					70 					-- packet type == 7 (PUBCOMP), flags == 0 (reserved bits: 0000)
					02 					-- variable length == 2 bytes
						0001 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.PUBCOMP, packet_id=0x1234
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					70 					-- packet type == 7 (PUBCOMP), flags == 0 (reserved bits: 0000)
					02 					-- variable length == 2 bytes
						1234 			-- packet id of acknowledged PUBLISH packet
				]]
			))
		)
	end)

	it("SUBSCRIBE", function()
		assert.are.same(
			{
				type=protocol.packet_type.SUBSCRIBE, packet_id=1, subscriptions={
					{
						topic = "some",
						qos = 0,
					},
				},
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					82 						-- packet type == 8 (SUBSCRIBE), flags == 0x2 (fixed value)
					09 						-- length == 9 bytes
						0001 				-- variable header: Packet Identifier == 1
							0004 736F6D65 	-- topic filter #1 == string "some"
							00 				-- QoS #1 == 0
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.SUBSCRIBE, packet_id=2, subscriptions={
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
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					82 						-- packet type == 8 (SUBSCRIBE), flags == 0x2 (fixed value)
					21 						-- length == 0x21 == 33 bytes
						0002 				-- variable header: Packet Identifier == 2
							0006 736F6D652F23 						-- topic filter #1 == string "some/#"
							00 										-- QoS #1
							000F 6F746865722F2B2F746F7069632F23 	-- topic filter #2 == string "other/+/topic/#"
							01 										-- QoS #2
							0001 23 								-- topic filter #3 == string "#"
							02 										-- QoS #3
				]]
			))
		)
	end)

	it("SUBACK", function()
		assert.are.same(
			{
				type=protocol.packet_type.SUBACK, packet_id=1, rc={0},
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					90 					-- packet type == 9 (SUBACK), flags == 0
					03 					-- variable length == 3 bytes
						0001 			-- packet id of acknowledged SUBSCRIBE packet
							00 			-- payload: return code, array of maximum allowed QoS-es
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.SUBACK, packet_id=0x1234, rc={0},
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					90 					-- packet type == 9 (SUBACK), flags == 0
					03 					-- variable length == 3 bytes
						1234 			-- packet id of acknowledged SUBSCRIBE packet
							00 			-- payload: return code, array of maximum allowed QoS-es
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.SUBACK, packet_id=0x1234, rc={3, 3, 0x80},
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					90 					-- packet type == 9 (SUBACK), flags == 0
					05 					-- variable length == 5 bytes
						1234 			-- packet id of acknowledged SUBSCRIBE packet
							03 03 80	-- payload: return code, array of maximum allowed QoS-es
				]]
			))
		)
	end)

	it("UNSUBSCRIBE", function()
		assert.are.same(
			{
				type=protocol.packet_type.UNSUBSCRIBE, packet_id=1, subscriptions={
					"some"
				},
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					A2 						-- packet type == 0xA == 10 (UNSUBSCRIBE), flags == 0x2 (fixed value)
					08 						-- length == 8 bytes
						0001 				-- variable header: Packet Identifier == 1
							0004 736F6D65 	-- topic filter #1 == string "some"
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.UNSUBSCRIBE, packet_id=0x1234, subscriptions = {
					"some/#",
					"other/+/topic/#",
					"#",
				},
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					A2 						-- packet type == 0xA == 10 (UNSUBSCRIBE), flags == 0x2 (fixed value)
					1E 						-- length == 0x1E == 30 bytes
						1234 				-- variable header: Packet Identifier == 0x1234
							0006 736F6D652F23 						-- topic filter #1 == string "some/#"
							000F 6F746865722F2B2F746F7069632F23 	-- topic filter #1 == string "other/+/topic/#"
							0001 23 								-- topic filter #1 == string "#"
				]]
			))
		)
	end)

	it("UNSUBACK", function()
		assert.are.same(
			{
				type=protocol.packet_type.UNSUBACK, packet_id=1,
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					B0 					-- packet type == 0xB == 11 (UNSUBACK), flags == 0
					02 					-- variable length == 2 bytes
						0001 			-- packet id of acknowledged UNSUBSCRIBE packet
				]]
			))
		)
		assert.are.same(
			{
				type=protocol.packet_type.UNSUBACK, packet_id=0x1234,
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					B0 					-- packet type == 0xB == 11 (UNSUBACK), flags == 0
					02 					-- variable length == 2 bytes
						1234 			-- packet id of acknowledged UNSUBSCRIBE packet
				]]
			))
		)
	end)

	it("PINGREQ", function()
		assert.are.same(
			{
				type=protocol.packet_type.PINGREQ,
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					C0 					-- packet type == 0xC == 12 (PINGREQ), flags == 0
					00 					-- variable length == 0 bytes
				]]
			))
		)
	end)

	it("PINGRESP", function()
		assert.are.same(
			{
				type=protocol.packet_type.PINGRESP,
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					D0 					-- packet type == 0xD == 13 (PINGRESP), flags == 0
					00 					-- variable length == 0 bytes
				]]
			))
		)
	end)

	it("DISCONNECT", function()
		assert.are.same(
			{
				type=protocol.packet_type.DISCONNECT,
			},
			protocol4.parse_packet(make_read_func_hex(
				extract_hex[[
					E0 					-- packet type == 0xE == 14 (DISCONNECT), flags == 0
					00 					-- variable length == 0 bytes
				]]
			))
		)
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
