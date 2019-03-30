-- busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/module-basics.lua
-- DOC v3.1.1: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html
-- DOC v5.0: http://docs.oasis-open.org/mqtt/mqtt/v5.0/cos01/mqtt-v5.0-cos01.html

describe("MQTT lua module", function()
	it("presented and it's a table", function()
		assert.is_table(require("mqtt"))
	end)
end)

describe("MQTT lua library component test:", function()
	local tools
	local protocol

	local extract_hex = require("./tests/extract_hex")

	it("modules presented", function()
		tools = require("mqtt.tools")
		protocol = require("mqtt.protocol")
		require("mqtt.client")
		require("mqtt.ioloop")
		require("mqtt.luasocket")
		require("mqtt.luasocket_ssl")
		require("mqtt.protocol4")
		require("mqtt.protocol5")
	end)

	it("tools.hex", function()
		assert.are.equal("", tools.hex(""))
		assert.are.equal("00", tools.hex("\000"))
		assert.are.equal("01", tools.hex("\001"))
		assert.are.equal("80", tools.hex("\128"))
		assert.are.equal("FF", tools.hex("\255"))
		assert.are.equal("FF00FF", tools.hex("\255\000\255"))
	end)

	it("extract_hex", function()
		assert.are.equal("", extract_hex(""))
		assert.are.equal("", extract_hex(" "))
		assert.are.equal("", extract_hex("\t"))
		assert.are.equal("", extract_hex([[

		]]))
		assert.are.equal("", extract_hex([[


		]]))
		assert.are.equal("01020304", extract_hex("01020304"))
		assert.are.equal("01020304", extract_hex("01020304    "))
		assert.are.equal("01020304", extract_hex("    01020304"))
		assert.are.equal("01020304", extract_hex("    01020304    "))
		assert.are.equal("01020304", extract_hex("    01020304  -- comment"))
		assert.are.equal("01020304", extract_hex([[
			01 -- is 01

			02
			03 04 -- other comment
		]]))
	end)

	it("tools.div", function()
		assert.are.equal(1, tools.div(3, 2))
		assert.are.equal(2, tools.div(4, 2))
	end)

	it("protocol.make_var_length", function()
		-- DOC v3.1.1: 2.2.3 Remaining Length
		-- DOC v5.0: 1.5.5 Variable Byte Integer
		assert.has.errors(function() protocol.make_var_length(0 - 1) end)
		assert.are.equal("00", tools.hex(string.char(protocol.make_var_length(0))))
		assert.are.equal("01", tools.hex(string.char(protocol.make_var_length(1))))
		assert.are.equal("7F", tools.hex(string.char(protocol.make_var_length(127))))
		assert.are.equal("8001", tools.hex(string.char(protocol.make_var_length(128))))
		assert.are.equal("FF7F", tools.hex(string.char(protocol.make_var_length(16383))))
		assert.are.equal("808001", tools.hex(string.char(protocol.make_var_length(16384))))
		assert.are.equal("FFFF7F", tools.hex(string.char(protocol.make_var_length(2097151))))
		assert.are.equal("80808001", tools.hex(string.char(protocol.make_var_length(2097152))))
		assert.are.equal("FFFFFF7F", tools.hex(string.char(protocol.make_var_length(268435455))))
		assert.has.errors(function() protocol.make_var_length(268435455 + 1) end)
	end)

	it("protocol.make_var_length_nonzero", function()
		-- DOC v3.1.1: 2.2.3 Remaining Length
		-- DOC v5.0: 1.5.5 Variable Byte Integer
		assert.has.errors(function() protocol.make_var_length_nonzero(0 - 1) end)
		assert.has.errors(function() protocol.make_var_length_nonzero(0) end)
		assert.are.equal("01", tools.hex(string.char(protocol.make_var_length_nonzero(1))))
		assert.are.equal("7F", tools.hex(string.char(protocol.make_var_length_nonzero(127))))
		assert.are.equal("8001", tools.hex(string.char(protocol.make_var_length_nonzero(128))))
		assert.are.equal("FF7F", tools.hex(string.char(protocol.make_var_length_nonzero(16383))))
		assert.are.equal("808001", tools.hex(string.char(protocol.make_var_length_nonzero(16384))))
		assert.are.equal("FFFF7F", tools.hex(string.char(protocol.make_var_length_nonzero(2097151))))
		assert.are.equal("80808001", tools.hex(string.char(protocol.make_var_length_nonzero(2097152))))
		assert.are.equal("FFFFFF7F", tools.hex(string.char(protocol.make_var_length_nonzero(268435455))))
		assert.has.errors(function() protocol.make_var_length_nonzero(268435455 + 1) end)
	end)

	it("protocol.make_uint8", function()
		assert.are.equal("00", tools.hex(protocol.make_uint8(0)))
		assert.are.equal("01", tools.hex(protocol.make_uint8(1)))
		assert.are.equal("32", tools.hex(protocol.make_uint8(0x32)))
		assert.are.equal("FF", tools.hex(protocol.make_uint8(0xFF)))
	end)

	it("protocol.make_uint8_0_or_1", function()
		assert.has.errors(function() tools.hex(protocol.make_uint8_0_or_1(0x00 - 1)) end)
		assert.are.equal("00", tools.hex(protocol.make_uint8_0_or_1(0x00)))
		assert.are.equal("01", tools.hex(protocol.make_uint8_0_or_1(0x01)))
		assert.has.errors(function() tools.hex(protocol.make_uint8_0_or_1(0x02)) end)
	end)

	it("protocol.make_uint16", function()
		assert.are.equal("0000", tools.hex(protocol.make_uint16(0)))
		assert.are.equal("0001", tools.hex(protocol.make_uint16(1)))
		assert.are.equal("0032", tools.hex(protocol.make_uint16(0x32)))
		assert.are.equal("00FF", tools.hex(protocol.make_uint16(0xFF)))
		assert.are.equal("0100", tools.hex(protocol.make_uint16(0x0100)))
		assert.are.equal("FF00", tools.hex(protocol.make_uint16(0xFF00)))
		assert.are.equal("7F4A", tools.hex(protocol.make_uint16(0x7F4A)))
		assert.are.equal("FFFF", tools.hex(protocol.make_uint16(0xFFFF)))
	end)

	it("protocol.make_uint16_nonzero", function()
		assert.has.error(function() tools.hex(protocol.make_uint16_nonzero(0)) end)
		assert.are.equal("0001", tools.hex(protocol.make_uint16_nonzero(1)))
		assert.are.equal("0032", tools.hex(protocol.make_uint16_nonzero(0x32)))
		assert.are.equal("00FF", tools.hex(protocol.make_uint16_nonzero(0xFF)))
		assert.are.equal("0100", tools.hex(protocol.make_uint16_nonzero(0x0100)))
		assert.are.equal("FF00", tools.hex(protocol.make_uint16_nonzero(0xFF00)))
		assert.are.equal("7F4A", tools.hex(protocol.make_uint16_nonzero(0x7F4A)))
		assert.are.equal("FFFF", tools.hex(protocol.make_uint16_nonzero(0xFFFF)))
	end)

	it("protocol.make_uint32", function()
		assert.are.equal("00000000", tools.hex(protocol.make_uint32(0)))
		assert.are.equal("00000001", tools.hex(protocol.make_uint32(1)))
		assert.are.equal("00000032", tools.hex(protocol.make_uint32(0x32)))
		assert.are.equal("000000FF", tools.hex(protocol.make_uint32(0xFF)))
		assert.are.equal("00000100", tools.hex(protocol.make_uint32(0x0100)))
		assert.are.equal("0000FF00", tools.hex(protocol.make_uint32(0xFF00)))
		assert.are.equal("00007F4A", tools.hex(protocol.make_uint32(0x7F4A)))
		assert.are.equal("0000FFFF", tools.hex(protocol.make_uint32(0xFFFF)))
		assert.are.equal("7FFFFFFF", tools.hex(protocol.make_uint32(0x7FFFFFFF)))
		assert.are.equal("FFFFFFFF", tools.hex(protocol.make_uint32(0xFFFFFFFF)))
	end)

	it("protocol.make_string", function()
		assert.are.equal("0000", tools.hex(protocol.make_string("")))
		assert.are.equal("00044D515454", tools.hex(protocol.make_string("MQTT")))
	end)

	-- returns read_func-compatible function reading given HEX string
	local function make_read_func(hex)
		local data = {}
		for i = 1, #hex / 2 do
			data[#data + 1] = string.char(tonumber(hex:sub((i * 2) - 1, i * 2), 16))
		end
		data = table.concat(data)
		local off = 1
		return function(size)
			if off + size - 1 > #data then
				return false, "no more data available"
			end
			local part = data:sub(off, off + size - 1)
			off = off + size
			return part
		end
	end

	it("protocol.parse_string", function()
		assert.is_false(protocol.parse_string(make_read_func("")))
		assert.is_false(protocol.parse_string(make_read_func("0001")))
		assert.are.equal("", protocol.parse_string(make_read_func("0000")))
		assert.are.equal(" ", protocol.parse_string(make_read_func("000120")))
		assert.are.equal("0", protocol.parse_string(make_read_func("000130")))
		assert.are.equal("MQTT", protocol.parse_string(make_read_func("00044D515454")))
	end)

	it("protocol.parse_uint8", function()
		assert.is_false(protocol.parse_uint8(make_read_func("")))
		assert.are.equal(0, protocol.parse_uint8(make_read_func("00")))
		assert.are.equal(1, protocol.parse_uint8(make_read_func("01")))
		assert.are.equal(0x32, protocol.parse_uint8(make_read_func("32")))
		assert.are.equal(0xFF, protocol.parse_uint8(make_read_func("FF")))
	end)

	it("protocol.parse_uint8_0_or_1", function()
		assert.is_false(protocol.parse_uint8_0_or_1(make_read_func("")))
		assert.are.equal(0, protocol.parse_uint8_0_or_1(make_read_func("00")))
		assert.are.equal(1, protocol.parse_uint8_0_or_1(make_read_func("01")))
		assert.is_false(protocol.parse_uint8_0_or_1(make_read_func("02")))
		assert.is_false(protocol.parse_uint8_0_or_1(make_read_func("FF")))
	end)

	it("protocol.parse_uint16", function()
		assert.is_false(protocol.parse_uint16(make_read_func("")))
		assert.are.equal(0, protocol.parse_uint16(make_read_func("0000")))
		assert.are.equal(1, protocol.parse_uint16(make_read_func("0001")))
		assert.are.equal(0x32, protocol.parse_uint16(make_read_func("0032")))
		assert.are.equal(0xBEEF, protocol.parse_uint16(make_read_func("BEEF")))
		assert.are.equal(0xFFFF, protocol.parse_uint16(make_read_func("FFFF")))
	end)

	it("protocol.parse_uint16_nonzero", function()
		assert.is_false(protocol.parse_uint16_nonzero(make_read_func("")))
		assert.is_false(protocol.parse_uint16_nonzero(make_read_func("0000")))
		assert.are.equal(1, protocol.parse_uint16_nonzero(make_read_func("0001")))
		assert.are.equal(0x32, protocol.parse_uint16_nonzero(make_read_func("0032")))
		assert.are.equal(0xBEEF, protocol.parse_uint16_nonzero(make_read_func("BEEF")))
		assert.are.equal(0xFFFF, protocol.parse_uint16_nonzero(make_read_func("FFFF")))
	end)

	it("protocol.parse_uint32", function()
		assert.is_false(protocol.parse_uint32(make_read_func("")))
		assert.are.equal(0, protocol.parse_uint32(make_read_func("00000000")))
		assert.are.equal(1, protocol.parse_uint32(make_read_func("00000001")))
		assert.are.equal(0x32, protocol.parse_uint32(make_read_func("00000032")))
		assert.are.equal(0xDEADBEEF, protocol.parse_uint32(make_read_func("DEADBEEF")))
		assert.are.equal(0x7FFFFFFF, protocol.parse_uint32(make_read_func("7FFFFFFF")))
		assert.are.equal(0xFFFFFFFF, protocol.parse_uint32(make_read_func("FFFFFFFF")))
	end)

	it("protocol.parse_var_length", function()
		-- DOC v3.1.1: 2.2.3 Remaining Length
		-- DOC v5.0: 1.5.5 Variable Byte Integer
		assert.is_false(protocol.parse_var_length(make_read_func("")))
		assert.are.equal(0, protocol.parse_var_length(make_read_func("00")))
		assert.are.equal(1, protocol.parse_var_length(make_read_func("01")))
		assert.are.equal(127, protocol.parse_var_length(make_read_func("7F")))
		assert.are.equal(128, protocol.parse_var_length(make_read_func("8001")))
		assert.are.equal(16383, protocol.parse_var_length(make_read_func("FF7F")))
		assert.are.equal(16384, protocol.parse_var_length(make_read_func("808001")))
		assert.are.equal(2097151, protocol.parse_var_length(make_read_func("FFFF7F")))
		assert.are.equal(2097152, protocol.parse_var_length(make_read_func("80808001")))
		assert.are.equal(268435455, protocol.parse_var_length(make_read_func("FFFFFF7F")))
		assert.is_false(protocol.parse_var_length(make_read_func("FFFFFFFF")))
	end)

	it("protocol.parse_var_length_nonzero", function()
		-- DOC v3.1.1: 2.2.3 Remaining Length
		-- DOC v5.0: 1.5.5 Variable Byte Integer
		assert.is_false(protocol.parse_var_length_nonzero(make_read_func("")))
		assert.is_false(protocol.parse_var_length_nonzero(make_read_func("00")))
		assert.are.equal(1, protocol.parse_var_length_nonzero(make_read_func("01")))
		assert.are.equal(127, protocol.parse_var_length_nonzero(make_read_func("7F")))
		assert.are.equal(128, protocol.parse_var_length_nonzero(make_read_func("8001")))
		assert.are.equal(16383, protocol.parse_var_length_nonzero(make_read_func("FF7F")))
		assert.are.equal(16384, protocol.parse_var_length_nonzero(make_read_func("808001")))
		assert.are.equal(2097151, protocol.parse_var_length_nonzero(make_read_func("FFFF7F")))
		assert.are.equal(2097152, protocol.parse_var_length_nonzero(make_read_func("80808001")))
		assert.are.equal(268435455, protocol.parse_var_length_nonzero(make_read_func("FFFFFF7F")))
		assert.is_false(protocol.parse_var_length_nonzero(make_read_func("FFFFFFFF")))

	end)

	it("protocol.next_packet_id", function()
		assert.has.errors(function() protocol.next_packet_id(0) end)
		assert.has.errors(function() protocol.next_packet_id("str") end)
		assert.are.equal(1, protocol.next_packet_id())
		assert.are.equal(2, protocol.next_packet_id(1))
		assert.are.equal(3, protocol.next_packet_id(2))
		assert.are.equal(0xFFFF - 1, protocol.next_packet_id(0xFFFF - 2))
		assert.are.equal(0xFFFF, protocol.next_packet_id(0xFFFF - 1))
		assert.are.equal(1, protocol.next_packet_id(0xFFFF))
	end)

	it("protocol.check_qos", function()
		assert.is_false(protocol.check_qos(-1))
		assert.is_true(protocol.check_qos(0))
		assert.is_true(protocol.check_qos(1))
		assert.is_true(protocol.check_qos(2))
		assert.is_false(protocol.check_qos(3))
	end)

	it("protocol.check_packet_id", function()
		assert.is_false(protocol.check_packet_id(-1))
		assert.is_false(protocol.check_packet_id(0))
		assert.is_true(protocol.check_packet_id(1))
		assert.is_true(protocol.check_packet_id(2))
		assert.is_true(protocol.check_packet_id(10))
		assert.is_true(protocol.check_packet_id(100))
		assert.is_true(protocol.check_packet_id(0xFFFF - 1))
		assert.is_true(protocol.check_packet_id(0xFFFF))
		assert.is_false(protocol.check_packet_id(0xFFFF + 1))
		assert.has.errors(function() protocol.check_packet_id() end)
	end)
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
