#!/usr/bin/env lua
local mqtt = require("mqtt")
local protocol = require("mqtt.protocol")
local protocol4 = require("mqtt.protocol4")
local protocol5 = require("mqtt.protocol5")
local extract_hex = require("mqtt.tools").extract_hex

local input_file_arg = arg[1]
local protocol_version_arg = arg[2]

local protocol_module


-- checking args
if not input_file_arg then
	print("Parse a HEX file with MQTT traffic")
	print()
	print("Usage:")
	print(string.format("    %s <input-file> [protocol-version]", arg[0]))
	print()
	print("    <input-file>       - path to the text file with HEX strings of MQTT protocol")
	print("    [protocol-version] - optional, either 4 or 5, for MQTT v3.1.1 or MQTT v5.0 respectively")
	print("                         will be auto-detected if not provided")
	os.exit(1)
end
if protocol_version_arg == "4" then
	protocol_module = protocol4
elseif protocol_version_arg == "5" then
	protocol_module = protocol5
end
print(string.format("-- using protocol version %s", protocol_version_arg))

-- reading hex file
local file = assert(io.open(input_file_arg), "failed to open input file")
local hex = file:read("*a")
hex = extract_hex(hex)

-- decode hex data
local data = {}
for i = 1, hex:len() / 2 do
	local byte = hex:sub(i*2 - 1, i*2)
	data[#data + 1] = string.char(tonumber(byte, 16))
end
data = table.concat(data)
local data_size = data:len()
local pos = 1
print(string.format("-- hex-decoded %d bytes from <input-file> %s", data_size, input_file_arg))

-- create read function
local function read_func(size)
	if pos > data_size then
		return false, "end of the input data"
	end
	local res = data:sub(pos, pos + size - 1)
	if res:len() ~= size then
		return false, "not enough unparsed data"
	end
	pos = pos + size
	return res
end

-- returns amount of the available input data
local function available()
	return data_size - pos + 1
end

-- parse all packets from the input file
while available() > 0 do
	local packet, err
	if not protocol_module then
		-- expecting a CONNECT packet first in the input
		packet, err = protocol.parse_packet_connect(read_func)
	else
		packet, err = protocol_module.parse_packet(read_func)
	end
	if not packet then
		print("next packet parsing error:", err)
		break
	end
	print(packet)
	if packet.type == protocol.packet_type.CONNECT and not protocol_module then
		if packet.version == mqtt.v311 then
			protocol_module = protocol4
		elseif packet.version == mqtt.v50 then
			protocol_module = protocol5
		else
			error("unexpected CONNECT packet version: "..tostring(packet.version))
		end
	end
end

print(string.format("-- done, %d bytes left in the input buffer", available()))
