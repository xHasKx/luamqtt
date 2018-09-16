-- busted -e 'package.path="./?/init.lua;"..package.path;' spec/*.lua
-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

describe("MQTT lua module", function()
	it("presented and it's a table", function()
		assert.is_table(require("mqtt"))
	end)
end)

describe("MQTT lua library component test:", function()
	local tools
	local protocol

	it("modules presented", function()
		tools = require("mqtt.tools")
		protocol = require("mqtt.protocol")
	end)

	it("tools.hex", function()
		assert.are.equal("", tools.hex(""))
		assert.are.equal("00", tools.hex("\000"))
		assert.are.equal("01", tools.hex("\001"))
		assert.are.equal("80", tools.hex("\128"))
		assert.are.equal("FF", tools.hex("\255"))
		assert.are.equal("FF00FF", tools.hex("\255\000\255"))
	end)

	it("tools.div", function()
		assert.are.equal(1, tools.div(3, 2))
		assert.are.equal(2, tools.div(4, 2))
	end)

	it("protocol.make_var_length", function()
		-- DOC: Table 2.4 Size of Remaining Length field
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

	it("protocol.make_uint8", function()
		assert.are.equal("00", tools.hex(protocol.make_uint8(0)))
		assert.are.equal("01", tools.hex(protocol.make_uint8(1)))
		assert.are.equal("32", tools.hex(protocol.make_uint8(0x32)))
		assert.are.equal("FF", tools.hex(protocol.make_uint8(0xFF)))
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

	it("protocol.make_string", function()
		assert.are.equal("0000", tools.hex(protocol.make_string("")))
		assert.are.equal("00044D515454", tools.hex(protocol.make_string("MQTT")))
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
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
