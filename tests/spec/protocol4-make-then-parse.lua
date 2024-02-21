-- busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/protocol4-make-then-parse.lua
-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

describe("MQTT v3.1.1 protocol: making and then parsing back all packets", function()
	local mqtt = require("mqtt")
	local tools = require("mqtt.tools")
	local protocol = require("mqtt.protocol")
	local protocol4 = require("mqtt.protocol4")

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
				version = mqtt.v311, -- NOTE: optional field, added only to make test work
				type = protocol.packet_type.CONNECT,
				id = "client-id",
				clean = true,
				will = {
					payload = "client-id is offline",
					topic = "offline",
					qos = 1,
					retain = true,
				},
				username = "TheUser",
				password = "TopSecret",
				keep_alive = 30,
			},
		},
		{
			title = "CONNACK",
			packet = {
				type = protocol.packet_type.CONNACK,
				sp = true, rc = 2,
			},
		},
		{
			title = "PUBLISH",
			packet = {
				type = protocol.packet_type.PUBLISH,
				topic = "some",
				payload = "payload",
				qos = 1,
				retain = true,
				dup = true,
				packet_id = 2,
			},
		},
		{
			title = "PUBACK",
			packet = {
				type = protocol.packet_type.PUBACK,
				packet_id = 3,
			},
		},
		{
			title = "PUBREC",
			packet = {
				type = protocol.packet_type.PUBREC,
				packet_id = 4,
			},
		},
		{
			title = "PUBREL",
			packet = {
				type = protocol.packet_type.PUBREL,
				packet_id = 5,
			},
		},
		{
			title = "PUBCOMP",
			packet = {
				type = protocol.packet_type.PUBCOMP,
				packet_id = 6,
			},
		},
		{
			title = "SUBSCRIBE",
			packet = {
				type = protocol.packet_type.SUBSCRIBE,
				packet_id = 7,
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
			},
		},
		{
			title = "SUBACK",
			packet = {
				type = protocol.packet_type.SUBACK,
				packet_id = 8,
				rc = { 0, 1, 2, 3, 0x80 },
			},
		},
		{
			title = "UNSUBSCRIBE",
			packet = {
				type = protocol.packet_type.UNSUBSCRIBE,
				packet_id = 9,
				subscriptions = {
					"some/#",
					"other/+/topic/#",
					"#",
				},
			},
		},
		{
			title = "UNSUBACK",
			packet = {
				type = protocol.packet_type.UNSUBACK,
				packet_id = 10,
			},
		},
		{
			title = "PINGREQ",
			packet = {
				type = protocol.packet_type.PINGREQ,
			},
		},
		{
			title = "PINGRESP",
			packet = {
				type = protocol.packet_type.PINGRESP,
			},
		},
		{
			title = "DISCONNECT",
			packet = {
				type = protocol.packet_type.DISCONNECT,
			},
		}
	}

	for _, test in ipairs(tests) do
		it(test.title, function()
			local expected_packet = test.packet
			local packet_hex = tools.hex(tostring(protocol4.make_packet(expected_packet)))
			local parsed_packet = protocol4.parse_packet(make_read_func_hex(packet_hex))
			assert.are.same(expected_packet, parsed_packet)
		end)
	end
end)

-- vim: ts=4 sts=4 sw=4 noet ft=lua
