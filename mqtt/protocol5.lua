--[[

Here is a MQTT v5.0 protocol implementation

MQTT v5.0 documentation (DOC):
	http://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html

]]

-- module table
local protocol5 = {}

-- load required stuff
local type = type
local error = error
local assert = assert
local ipairs = ipairs
local require = require
local tostring = tostring
local setmetatable = setmetatable

local table = require("table")
local unpack = table.unpack or unpack
local tbl_sort = table.sort

local string = require("string")
local str_char = string.char
local fmt = string.format

local const = require("mqtt.const")
local const_v50 = const.v50

local tools = require("mqtt.tools")
local sortedpairs = tools.sortedpairs

local bit = require("mqtt.bitwrap")
local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local protocol = require("mqtt.protocol")
local make_uint8 = protocol.make_uint8
local make_uint16 = protocol.make_uint16
local make_uint32 = protocol.make_uint32
local make_string = protocol.make_string
local make_var_length = protocol.make_var_length
local parse_var_length = protocol.parse_var_length
local make_uint8_0_or_1 = protocol.make_uint8_0_or_1
local make_uint16_nonzero = protocol.make_uint16_nonzero
local make_var_length_nonzero = protocol.make_var_length_nonzero
local parse_string = protocol.parse_string
local parse_uint8 = protocol.parse_uint8
local parse_uint8_0_or_1 = protocol.parse_uint8_0_or_1
local parse_uint16 = protocol.parse_uint16
local parse_uint16_nonzero = protocol.parse_uint16_nonzero
local parse_uint32 = protocol.parse_uint32
local parse_var_length_nonzero = protocol.parse_var_length_nonzero
local make_header = protocol.make_header
local check_qos = protocol.check_qos
local check_packet_id = protocol.check_packet_id
local combine = protocol.combine
local packet_type = protocol.packet_type
local packet_mt = protocol.packet_mt
local connack_packet_mt = protocol.connack_packet_mt
local start_parse_packet = protocol.start_parse_packet
local parse_packet_connect_input = protocol.parse_packet_connect_input

-- Returns true if given value is a valid Retain Handling option, DOC: 3.8.3.1 Subscription Options
local function check_retain_handling(val)
	return (val == 0) or (val == 1) or (val == 2)
end

-- Create Connect Flags data, DOC: 3.1.2.3 Connect Flags
local function make_connect_flags(args)
	local byte = 0 -- bit 0 should be zero
	-- DOC: 3.1.2.4 Clean Start
	if args.clean ~= nil then
		assert(type(args.clean) == "boolean", "expecting .clean to be a boolean")
		if args.clean then
			byte = bor(byte, lshift(1, 1))
		end
	end
	-- DOC: 3.1.2.5 Will Flag
	if args.will ~= nil then
		-- check required args are presented
		assert(type(args.will) == "table", "expecting .will to be a table")
		assert(type(args.will.payload) == "string", "expecting .will.payload to be a string")
		assert(type(args.will.topic) == "string", "expecting .will.topic to be a string")
		assert(type(args.will.qos) == "number", "expecting .will.qos to be a number")
		assert(check_qos(args.will.qos), "expecting .will.qos to be a valid QoS value")
		assert(type(args.will.retain) == "boolean", "expecting .will.retain to be a boolean")
		if args.will.properties ~= nil then
			assert(type(args.will.properties) == "table", "expecting .will.properties to be a table")
		end
		if args.will.user_properties ~= nil then
			assert(type(args.will.user_properties) == "table", "expecting .will.user_properties to be a table")
		end
		-- will flag should be set to 1
		byte = bor(byte, lshift(1, 2))
		-- DOC: 3.1.2.6 Will QoS
		byte = bor(byte, lshift(args.will.qos, 3))
		-- DOC: 3.1.2.7 Will Retain
		if args.will.retain then
			byte = bor(byte, lshift(1, 5))
		end
	end
	-- DOC: 3.1.2.8 User Name Flag
	if args.username ~= nil then
		assert(type(args.username) == "string", "expecting .username to be a string")
		byte = bor(byte, lshift(1, 7))
	end
	-- DOC: 3.1.2.9 Password Flag
	if args.password ~= nil then
		assert(type(args.password) == "string", "expecting .password to be a string")
		assert(args.username, "the .username is required to set .password")
		byte = bor(byte, lshift(1, 6))
	end
	return make_uint8(byte)
end

-- Known property names and its identifiers, DOC: 2.2.2.2 Property
local property_pairs = {
	{ 0x01, "payload_format_indicator",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
	{ 0x02, "message_expiry_interval",
		make = make_uint32,
		parse = parse_uint32, },
	{ 0x03, "content_type",
		make = make_string,
		parse = parse_string, },
	{ 0x08, "response_topic",
		make = make_string,
		parse = parse_string, },
	{ 0x09, "correlation_data",
		make = make_string,
		parse = parse_string, },
	{ 0x0B, "subscription_identifiers",
		make = function(value) return str_char(make_var_length_nonzero(value)) end,
		parse = parse_var_length_nonzero,
		multiple = true, },
	{ 0x11, "session_expiry_interval",
		make = make_uint32,
		parse = parse_uint32, },
	{ 0x12, "assigned_client_identifier",
		make = make_string,
		parse = parse_string, },
	{ 0x13, "server_keep_alive",
		make = make_uint16,
		parse = parse_uint16, },
	{ 0x15, "authentication_method",
		make = make_string,
		parse = parse_string, },
	{ 0x16, "authentication_data",
		make = make_string,
		parse = parse_string, },
	{ 0x17, "request_problem_information",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
	{ 0x18, "will_delay_interval",
		make = make_uint32,
		parse = parse_uint32, },
	{ 0x19, "request_response_information",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
	{ 0x1A, "response_information",
		make = make_string,
		parse = parse_string, },
	{ 0x1C, "server_reference",
		make = make_string,
		parse = parse_string, },
	{ 0x1F, "reason_string",
		make = make_string,
		parse = parse_string, },
	{ 0x21, "receive_maximum",
		make = make_uint16,
		parse = parse_uint16, },
	{ 0x22, "topic_alias_maximum",
		make = make_uint16,
		parse = parse_uint16, },
	{ 0x23, "topic_alias",
		make = make_uint16_nonzero,
		parse = parse_uint16_nonzero, },
	{ 0x24, "maximum_qos",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
	{ 0x25, "retain_available",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
	{ 0x26, "user_property", -- NOTE: not implemented intentionally
		make = function(value_) error("not implemented") end, -- luacheck: ignore
		parse = function(read_func_) error("not implemented") end, }, -- luacheck: ignore
	{ 0x27, "maximum_packet_size",
		make = make_uint32,
		parse = parse_uint32, },
	{ 0x28, "wildcard_subscription_available",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
	{ 0x29, "subscription_identifiers_available",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
	{ 0x2A, "shared_subscription_available",
		make = make_uint8_0_or_1,
		parse = parse_uint8_0_or_1, },
}

-- properties table with keys in two directions: from name to identifier and back
local properties = {}
-- table with property value make functions
local property_make = {}
-- table with property value parse function
local property_parse = {}
-- table with property multiple flag
local property_multiple = {}
-- fill the properties and property_make tables
for _, prop in ipairs(property_pairs) do
	properties[prop[2]] = prop[1]				-- name ==> identifier
	properties[prop[1]] = prop[2]				-- identifier ==> name
	property_make[prop[1]] = prop.make			-- identifier ==> make function
	property_parse[prop[1]] = prop.parse		-- identifier ==> make function
	property_multiple[prop[1]] = prop.multiple	-- identifier ==> multiple flag
end

-- Allowed properties per packet type
local allowed_properties = {
	[packet_type.CONNECT] = {
		[0x11] = true, -- DOC: 3.1.2.11.2 Session Expiry Interval
		[0x21] = true, -- DOC: 3.1.2.11.3 Receive Maximum
		[0x27] = true, -- DOC: 3.1.2.11.4 Maximum Packet Size
		[0x22] = true, -- DOC: 3.1.2.11.5 Topic Alias Maximum
		[0x19] = true, -- DOC: 3.1.2.11.6 Request Response Information
		[0x17] = true, -- DOC: 3.1.2.11.7 Request Problem Information
		[0x26] = true, -- DOC: 3.1.2.11.8 User Property
		[0x15] = true, -- DOC: 3.1.2.11.9 Authentication Method
		[0x16] = true, -- DOC: 3.1.2.11.10 Authentication Data
	},
	[packet_type.CONNACK] = {
		[0x11] = true, -- DOC: 3.2.2.3.2 Session Expiry Interval
		[0x21] = true, -- DOC: 3.2.2.3.3 Receive Maximum
		[0x24] = true, -- DOC: 3.2.2.3.4 Maximum QoS
		[0x25] = true, -- DOC: 3.2.2.3.5 Retain Available
		[0x27] = true, -- DOC: 3.2.2.3.6 Maximum Packet Size
		[0x12] = true, -- DOC: 3.2.2.3.7 Assigned Client Identifier
		[0x22] = true, -- DOC: 3.2.2.3.8 Topic Alias Maximum
		[0x1F] = true, -- DOC: 3.2.2.3.9 Reason String
		[0x26] = true, -- DOC: 3.2.2.3.10 User Property
		[0x28] = true, -- DOC: 3.2.2.3.11 Wildcard Subscription Available
		[0x29] = true, -- DOC: 3.2.2.3.12 Subscription Identifiers Available
		[0x2A] = true, -- DOC: 3.2.2.3.13 Shared Subscription Available
		[0x13] = true, -- DOC: 3.2.2.3.14 Server Keep Alive
		[0x1A] = true, -- DOC: 3.2.2.3.15 Response Information
		[0x1C] = true, -- DOC: 3.2.2.3.16 Server Reference
		[0x15] = true, -- DOC: 3.2.2.3.17 Authentication Method
		[0x16] = true, -- DOC: 3.2.2.3.18 Authentication Data
	},
	[packet_type.PUBLISH] = {
		[0x01] = true, -- DOC: 3.3.2.3.2 Payload Format Indicator
		[0x02] = true, -- DOC: 3.3.2.3.3 Message Expiry Interval
		[0x23] = true, -- DOC: 3.3.2.3.4 Topic Alias
		[0x08] = true, -- DOC: 3.3.2.3.5 Response Topic
		[0x09] = true, -- DOC: 3.3.2.3.6 Correlation Data
		[0x26] = true, -- DOC: 3.3.2.3.7 User Property
		[0x0B] = true, -- DOC: 3.3.2.3.8 Subscription Identifier
		[0x03] = true, -- DOC: 3.3.2.3.9 Content Type
	},
	will = {
		[0x18] = true, -- DOC: 3.1.3.2.2 Will Delay Interval
		[0x01] = true, -- DOC: 3.1.3.2.3 Payload Format Indicator
		[0x02] = true, -- DOC: 3.1.3.2.4 Message Expiry Interval
		[0x03] = true, -- DOC: 3.1.3.2.5 Content Type
		[0x08] = true, -- DOC: 3.1.3.2.6 Response Topic
		[0x09] = true, -- DOC: 3.1.3.2.7 Correlation Data
		[0x26] = true, -- DOC: 3.1.3.2.8 User Property
	},
	[packet_type.PUBACK] = {
		[0x1F] = true, -- DOC: 3.4.2.2.2 Reason String
		[0x26] = true, -- DOC: 3.4.2.2.3 User Property
	},
	[packet_type.PUBREC] = {
		[0x1F] = true, -- DOC: 3.5.2.2.2 Reason String
		[0x26] = true, -- DOC: 3.5.2.2.3 User Property
	},
	[packet_type.PUBREL] = {
		[0x1F] = true, -- DOC: 3.6.2.2.2 Reason String
		[0x26] = true, -- DOC: 3.6.2.2.3 User Property
	},
	[packet_type.PUBCOMP] = {
		[0x1F] = true, -- DOC: 3.7.2.2.2 Reason String
		[0x26] = true, -- DOC: 3.7.2.2.3 User Property
	},
	[packet_type.SUBSCRIBE] = {
		[0x0B] = { multiple=false }, -- DOC: 3.8.2.1.2 Subscription Identifier -- DOC: It is a Protocol Error to include the Subscription Identifier more than once.
		[0x26] = true, -- DOC: 3.8.2.1.3 User Property
	},
	[packet_type.SUBACK] = {
		[0x1F] = true, -- DOC: 3.9.2.1.2 Reason String
		[0x26] = true, -- DOC: 3.9.2.1.3 User Property
	},
	[packet_type.UNSUBSCRIBE] = {
		[0x26] = true, -- DOC: 3.10.2.1.2 User Property
	},
	[packet_type.UNSUBACK] = {
		[0x1F] = true, -- DOC: 3.11.2.1.2 Reason String
		[0x26] = true, -- DOC: 3.11.2.1.3 User Property
	},
	-- NOTE: PINGREQ (3.12), PINGRESP (3.13) has no properties
	[packet_type.DISCONNECT] = {
		[0x11] = true, -- DOC: 3.14.2.2.2 Session Expiry Interval
		[0x1F] = true, -- DOC: 3.14.2.2.3 Reason String
		[0x26] = true, -- DOC: 3.14.2.2.4 User Property
		[0x1C] = true, -- DOC: 3.14.2.2.5 Server Reference
	},
	[packet_type.AUTH] = {
		[0x15] = true, -- DOC: 3.15.2.2.2 Authentication Method
		[0x16] = true, -- DOC: 3.15.2.2.3 Authentication Data
		[0x1F] = true, -- DOC: 3.15.2.2.4 Reason String
		[0x26] = true, -- DOC: 3.15.2.2.5 User Property
	},
}

-- Create properties field for various control packets, DOC: 2.2.2 Properties
local function make_properties(ptype, args)
	local allowed = assert(allowed_properties[ptype], "invalid packet type to detect allowed properties")
	local props = ""
	local uprop_id = properties.user_property
	-- writing known properties
	if args.properties ~= nil then
		assert(type(args.properties) == "table", "expecting .properties to be a table")
		-- validate all properties and append them to order list
		local order = {}
		for name, value in sortedpairs(args.properties) do
			assert(type(name) == "string", "expecting property name to be a string: "..tostring(name))
			-- detect property identifier and check it's allowed for that packet type
			local prop_id = assert(properties[name], "unknown property: "..tostring(name))
			assert(prop_id ~= uprop_id, "user properties should be passed in .user_properties table")
			if not allowed[prop_id] then
				error("property "..name.." is not allowed for packet type "..packet_type[ptype])
			end
			order[#order + 1] = { prop_id, name, value }
		end
		-- sort props in the identifier ascending order
		tbl_sort(order, function(a, b) return a[1] < b[1] end)
		for _, item in ipairs(order) do
			local prop_id, name,  value = unpack(item)
			if property_multiple[prop_id] then
				assert(type(value) == "table", "expecting list-table for property with multiple value")
				assert(#value == 1, "only one value for multiple-property supported")
				value = value[1]
			end
			-- make property data
			local ok, val = pcall(property_make[prop_id], value)
			if not ok then
				error("invalid property value: "..name.." = "..tostring(value)..": "..tostring(val))
			end
			local prop = combine(
				str_char(make_var_length(prop_id)),
				val
			)
			-- and append it to props
			if type(props) == "string" then
				props = combine(prop)
			else
				props:append(prop)
			end
		end
	end
	-- writing userproperties
	if args.user_properties ~= nil then
		assert(type(args.user_properties) == "table", "expecting .user_properties to be a table")
		assert(allowed[uprop_id], "user_property is not allowed for packet type "..ptype)
		local order = {}
		local dups = {}
		if args.user_properties[1] then
			-- at first use array items as they given as {name, value} pairs with stable order
			for i, pair in ipairs(args.user_properties) do
				-- validate types for name and value
				if type(pair) ~= "table" then
					error(fmt("user property at position %d should be {name, value} table", i))
				end
				if type(pair[1]) ~= "string" then
					error(fmt("user property name at position %d should be a string", i))
				end
				if type(pair[2]) ~= "string" then
					error(fmt("user property '%s' value at position %d should be a string", pair[1], i))
				end
				order[i] = pair
				dups[pair[1]] = pair[2]
			end
		end
		-- now add the rest of user properties given as string table keys
		for name, val in sortedpairs(args.user_properties) do
			if type(name) ~= "number" then -- skipping number keys as they already added above
				-- validate types for name and value
				if type(name) ~= "string" then
					error(fmt("user property name '%s' should be a string", name))
				end
				if type(val) ~= "string" then
					error(fmt("user property '%s' value '%s' should be a string", name, val))
				end
				-- check that name+value key already added
				if dups[name] ~= val then
					order[#order + 1] = {name, val}
				end
			end
		end
		for _, pair in ipairs(order) do
			local name = pair[1]
			local value = pair[2]
			-- make user property data
			local prop = combine(
				str_char(make_var_length(uprop_id)),
				make_string(name),
				make_string(value)
			)
			-- and append it to props
			if type(props) == "string" then
				props = combine(prop)
			else
				props:append(prop)
			end
		end
	end
	-- and combine properties with its length field
	return combine(
		str_char(make_var_length(props:len())),		-- DOC: 2.2.2.1 Property Length
		props										-- DOC: 2.2.2.2 Property
	)
end

-- Create CONNECT packet, DOC: 3.1 CONNECT – Connection Request
local function make_packet_connect(args)
	-- check args
	assert(type(args.id) == "string", "expecting .id to be a string with MQTT client id")
	-- DOC: 3.1.2.10 Keep Alive
	local keep_alive_ival = 0
	if args.keep_alive then
		assert(type(args.keep_alive) == "number")
		keep_alive_ival = args.keep_alive
	end
	-- DOC: 3.1.2.11 CONNECT Properties
	local props = make_properties(packet_type.CONNECT, args)
	-- DOC: 3.1.2 CONNECT Variable Header
	local variable_header = combine(
		make_string("MQTT"), 				-- DOC: 3.1.2.1 Protocol Name
		make_uint8(5), 						-- DOC: 3.1.2.2 Protocol Version (5 is for MQTT v5.0)
		make_connect_flags(args), 			-- DOC: 3.1.2.3 Connect Flags
		make_uint16(keep_alive_ival), 		-- DOC: 3.1.2.10 Keep Alive
		props								-- DOC: 3.1.2.11 CONNECT Properties
	)
	-- DOC: 3.1.3 CONNECT Payload
	-- DOC: 3.1.3.1 Client Identifier (ClientID)
	local payload = combine(
		make_string(args.id)
	)
	if args.will then
		-- DOC: 3.1.3.2 Will Properties
		payload:append(make_properties("will", args.will))
		-- DOC: 3.1.3.3 Will Topic
		assert(type(args.will.topic) == "string", "expecting will.topic to be a string")
		payload:append(make_string(args.will.topic))
		-- DOC: 3.1.3.4 Will Payload
		assert(args.will.payload == nil or type(args.will.payload) == "string", "expecting will.payload to be a string or nil")
		payload:append(make_string(args.will.payload))
	end
	if args.username then
		-- DOC: 3.1.3.5 User Name
		payload:append(make_string(args.username))
		if args.password then
			-- DOC: 3.1.3.6 Password
			payload:append(make_string(args.password))
		end
	end
	-- DOC: 3.1.1 Fixed header
	local header = make_header(packet_type.CONNECT, 0, variable_header:len() + payload:len())
	return combine(header, variable_header, payload)
end

-- Create CONNACK packet, DOC: 3.2 CONNACK – Connect acknowledgement
local function make_packet_connack(args)
	-- check args
	assert(type(args.sp) == "boolean", "expecting .sp to be a boolean with Session Present flag")
	assert(type(args.rc) == "number", "expecting .rc to be a number with Connect Reason Code")
	-- DOC: 3.2.2 CONNACK Variable Header
	local props = make_properties(packet_type.CONNACK, args)
	local variable_header = combine(
		make_uint8(args.sp and 1 or 0),		-- DOC: 3.2.2.1.1 Session Present
		make_uint8(args.rc),				-- DOC: 3.2.2.2 Connect Reason Code
		props								-- DOC: 3.2.2.3 CONNACK Properties
	)
	-- DOC: 3.2.3 CONNACK Payload
	-- DOC: The CONNACK packet has no Payload.
	-- DOC: 3.2.1 CONNACK Fixed Header
	local header = make_header(packet_type.CONNACK, 0, variable_header:len())
	return combine(header, variable_header)
end

-- Create PUBLISH packet, DOC: 3.3 PUBLISH – Publish message
local function make_packet_publish(args)
	-- check args
	assert(type(args.topic) == "string", "expecting .topic to be a string")
	if args.payload ~= nil then
		assert(type(args.payload) == "string", "expecting .payload to be a string")
	end
	if args.qos ~= nil then
		assert(type(args.qos) == "number", "expecting .qos to be a number")
		assert(check_qos(args.qos), "expecting .qos to be a valid QoS value")
	end
	if args.retain ~= nil then
		assert(type(args.retain) == "boolean", "expecting .retain to be a boolean")
	end
	if args.dup ~= nil then
		assert(type(args.dup) == "boolean", "expecting .dup to be a boolean")
	end

	-- DOC: 3.3.1 PUBLISH Fixed Header
	local flags = 0
	-- 3.3.1.3 RETAIN
	if args.retain then
		flags = bor(flags, 0x1)
	end
	-- DOC: 3.3.1.2 QoS
	flags = bor(flags, lshift(args.qos or 0, 1))
	-- DOC: 3.3.1.1 DUP
	if args.dup then
		flags = bor(flags, lshift(1, 3))
	end
	-- DOC: 3.3.2 PUBLISH Variable Header
	local variable_header = combine(
		make_string(args.topic)
	)
	-- DOC: 3.3.2.2 Packet Identifier
	if args.qos and args.qos > 0 then
		assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
		assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
		variable_header:append(make_uint16(args.packet_id))
	end
	-- DOC: 3.3.2.3 PUBLISH Properties
	variable_header:append(make_properties(packet_type.PUBLISH, args))
	-- DOC: 3.3.3 PUBLISH Payload
	local payload
	if args.payload then
		payload = args.payload
	else
		payload = ""
	end
	-- DOC: 3.3.1 Fixed header
	local header = make_header(packet_type.PUBLISH, flags, variable_header:len() + payload:len())
	return combine(header, variable_header, payload)
end

-- Create PUBACK packet, DOC: 3.4 PUBACK – Publish acknowledgement
local function make_packet_puback(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.rc) == "number", "expecting .rc to be a number")
	-- DOC: 3.4.2 PUBACK Variable Header
	local variable_header = combine(make_uint16(args.packet_id))
	local props = make_properties(packet_type.PUBACK, args)		-- DOC: 3.4.2.2 PUBACK Properties
	-- DOC: The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Success) and there are no Properties. In this case the PUBACK has a Remaining Length of 2.
	if props:len() > 1 or args.rc ~= 0 then
		variable_header:append(make_uint8(args.rc))				-- DOC: 3.4.2.1 PUBACK Reason Code
		variable_header:append(props)							-- DOC: 3.4.2.2 PUBACK Properties
	end
	-- DOC: 3.4.1 PUBACK Fixed Header
	local header = make_header(packet_type.PUBACK, 0, variable_header:len())
	return combine(header, variable_header)
end

-- Create PUBREC packet, DOC: 3.5 PUBREC – Publish received (QoS 2 delivery part 1)
local function make_packet_pubrec(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.rc) == "number", "expecting .rc to be a number")
	-- DOC: 3.5.2 PUBREC Variable Header
	local variable_header = combine(make_uint16(args.packet_id))
	local props = make_properties(packet_type.PUBREC, args)		-- DOC: 3.5.2.2 PUBREC Properties
	-- DOC: The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Success) and there are no Properties. In this case the PUBREC has a Remaining Length of 2.
	if props:len() > 1 or args.rc ~= 0 then
		variable_header:append(make_uint8(args.rc))				-- DOC: 3.5.2.1 PUBREC Reason Code
		variable_header:append(props)							-- DOC: 3.5.2.2 PUBREC Properties
	end
	-- DOC: 3.5.1 PUBREC Fixed Header
	local header = make_header(packet_type.PUBREC, 0, variable_header:len())
	return combine(header, variable_header)
end

-- Create PUBREL packet, DOC: 3.6 PUBREL – Publish release (QoS 2 delivery part 2)
local function make_packet_pubrel(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.rc) == "number", "expecting .rc to be a number")
	-- DOC: 3.6.2 PUBREL Variable Header
	local variable_header = combine(make_uint16(args.packet_id))
	local props = make_properties(packet_type.PUBREL, args)		-- DOC: 3.6.2.2 PUBREL Properties
	-- DOC: The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Success) and there are no Properties. In this case the PUBREL has a Remaining Length of 2.
	if props:len() > 1 or args.rc ~= 0 then
		variable_header:append(make_uint8(args.rc))				-- DOC: 3.6.2.1 PUBREL Reason Code
		variable_header:append(props)							-- DOC: 3.6.2.2 PUBREL Properties
	end
	-- DOC: 3.6.1 PUBREL Fixed Header
	local header = make_header(packet_type.PUBREL, 2, variable_header:len()) -- flags: fixed 0010 bits, DOC: Figure 3‑14 – PUBREL packet Fixed Header
	return combine(header, variable_header)
end

-- Create PUBCOMP packet, DOC: 3.7 PUBCOMP – Publish complete (QoS 2 delivery part 3)
local function make_packet_pubcomp(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.rc) == "number", "expecting .rc to be a number")
	-- DOC: 3.7.2 PUBCOMP Variable Header
	local variable_header = combine(make_uint16(args.packet_id))
	local props = make_properties(packet_type.PUBCOMP, args)	-- DOC: 3.7.2.2 PUBCOMP Properties
	-- DOC: The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Success) and there are no Properties. In this case the PUBCOMP has a Remaining Length of 2.
	if props:len() > 1 or args.rc ~= 0 then
		variable_header:append(make_uint8(args.rc))				-- DOC: 3.7.2.1 PUBCOMP Reason Code
		variable_header:append(props)							-- DOC: 3.7.2.2 PUBCOMP Properties
	end
	-- DOC: 3.7.1 PUBCOMP Fixed Header
	local header = make_header(packet_type.PUBCOMP, 0, variable_header:len())
	return combine(header, variable_header)
end

-- Create SUBSCRIBE packet, DOC: 3.8 SUBSCRIBE - Subscribe request
local function make_packet_subscribe(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.subscriptions) == "table", "expecting .subscriptions to be a table")
	assert(#args.subscriptions > 0, "expecting .subscriptions to be a non-empty array")
	-- DOC: 3.8.2 SUBSCRIBE Variable Header
	local variable_header = combine(
		make_uint16(args.packet_id),
		make_properties(packet_type.SUBSCRIBE, args)	-- DOC: 3.8.2.1 SUBSCRIBE Properties
	)
	-- DOC: 3.8.3 SUBSCRIBE Payload
	local payload = combine()
	for i, subscription in ipairs(args.subscriptions) do
		assert(type(subscription) == "table", "expecting .subscriptions["..i.."] to be a table")
		assert(type(subscription.topic) == "string", "expecting .subscriptions["..i.."].topic to be a string")
		if subscription.qos ~= nil then
			assert(type(subscription.qos) == "number", "expecting .subscriptions["..i.."].qos to be a number")
			assert(check_qos(subscription.qos), "expecting .subscriptions["..i.."].qos to be a valid QoS value")
		end
		if subscription.retain_as_published ~= nil then
			assert(type(subscription.retain_as_published) == "boolean", "expecting .subscriptions["..i.."].retain_as_published to be a boolean")
		end
		if subscription.retain_handling ~= nil then
			assert(type(subscription.retain_handling) == "number", "expecting .subscriptions["..i.."].retain_handling to be a number")
			assert(check_retain_handling(subscription.retain_handling), "expecting .subscriptions["..i.."].retain_handling to be a valid Retain Handling option")
		end
		-- DOC: 3.8.3.1 Subscription Options
		local so = subscription.qos or 0
		if subscription.no_local then
			so = bor(so, 4) -- set Bit 2
		end
		if subscription.retain_as_published then
			so = bor(so, 8) -- set Bit 3
		end
		if subscription.retain_handling then
			so = bor(so, lshift(subscription.retain_handling, 4)) -- set Bit 4 and 5
		end
		payload:append(make_string(subscription.topic))
		payload:append(make_uint8(so))
	end
	-- DOC: 3.8.1 SUBSCRIBE Fixed Header
	local header = make_header(packet_type.SUBSCRIBE, 2, variable_header:len() + payload:len()) -- flags: fixed 0010 bits, DOC: Figure 3‑18 SUBSCRIBE packet Fixed Header
	return combine(header, variable_header, payload)
end

-- Create SUBACK packet, DOC: 3.9 SUBACK – Subscribe acknowledgement
local function make_packet_suback(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.rc) == "table", "expecting .rc to be a table")
	assert(#args.rc > 0, "expecting .rc to be a non-empty array")
	-- DOC: 3.9.2 SUBACK Variable Header
	local variable_header = combine(
		make_uint16(args.packet_id),
		make_properties(packet_type.SUBACK, args)	-- DOC: 3.9.2.1 SUBACK Properties
	)
	-- DOC: 3.9.3 SUBACK Payload
	local payload = combine()
	for i, rc in ipairs(args.rc) do
		assert(type(rc) == "number", "expecting .rc["..i.."] to be a number")
		assert(rc >= 0 and rc <= 255, "expecting .rc["..i.."] to be in range [0, 255]")
		payload:append(make_uint8(rc))
	end
	-- DOC: 3.9.1 SUBACK Fixed Header
	local header = make_header(packet_type.SUBACK, 0, variable_header:len() + payload:len()) -- NOTE: fixed flags value 0x0
	return combine(header, variable_header, payload)
end

-- Create UNSUBSCRIBE packet, DOC: 3.10 UNSUBSCRIBE – Unsubscribe request
local function make_packet_unsubscribe(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.subscriptions) == "table", "expecting .subscriptions to be a table")
	assert(#args.subscriptions > 0, "expecting .subscriptions to be a non-empty array")
	-- DOC: 3.10.2 UNSUBSCRIBE Variable Header
	local variable_header = combine(
		make_uint16(args.packet_id),
		make_properties(packet_type.UNSUBSCRIBE, args)	-- DOC: 3.10.2.1 UNSUBSCRIBE Properties
	)
	-- DOC: 3.10.3 UNSUBSCRIBE Payload
	local payload = combine()
	for i, subscription in ipairs(args.subscriptions) do
		assert(type(subscription) == "string", "expecting .subscriptions["..i.."] to be a string")
		payload:append(make_string(subscription))
	end
	-- DOC: 3.10.1 UNSUBSCRIBE Fixed Header
	local header = make_header(packet_type.UNSUBSCRIBE, 2, variable_header:len() + payload:len()) -- flags: fixed 0010 bits, DOC: Figure 3.28 – UNSUBSCRIBE packet Fixed Header
	return combine(header, variable_header, payload)
end

-- Create UNSUBACK packet, DOC: 3.11 UNSUBACK – Unsubscribe acknowledgement
local function make_packet_unsuback(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.rc) == "table", "expecting .rc to be a table")
	assert(#args.rc > 0, "expecting .rc to be a non-empty array")
	-- DOC: 3.11.2 UNSUBACK Variable Header
	local variable_header = combine(
		make_uint16(args.packet_id),
		make_properties(packet_type.UNSUBACK, args)	-- DOC: 3.11.2.1 UNSUBACK Properties
	)
	-- DOC: 3.11.3 UNSUBACK Payload
	local payload = combine()
	for i, rc in ipairs(args.rc) do
		assert(type(rc) == "number", "expecting .rc["..i.."] to be a number")
		assert(rc >= 0 and rc <= 255, "expecting .rc["..i.."] to be in range [0, 255]")
		payload:append(make_uint8(rc))
	end
	-- DOC: 3.11.1 UNSUBACK Fixed Header
	local header = make_header(packet_type.UNSUBACK, 0, variable_header:len() + payload:len()) -- NOTE: fixed flags value 0x0
	return combine(header, variable_header, payload)
end

-- Create DISCONNECT packet, DOC: 3.14 DISCONNECT – Disconnect notification
local function make_packet_disconnect(args)
	-- check args
	assert(type(args.rc) == "number", "expecting .rc to be a number")
	-- DOC: 3.14.2 DISCONNECT Variable Header
	local variable_header = combine()
	local props = make_properties(packet_type.DISCONNECT, args)	-- DOC: 3.14.2.2 DISCONNECT Properties
	-- DOC: The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Normal disconnecton) and there are no Properties. In this case the DISCONNECT has a Remaining Length of 0.
	if props:len() > 1 or args.rc ~= 0 then
		variable_header:append(make_uint8(args.rc))				-- DOC: 3.14.2.1 Disconnect Reason Code
		variable_header:append(props)							-- DOC: 3.14.2.2 DISCONNECT Properties
	end
	-- DOC: 3.14.1 DISCONNECT Fixed Header
	local header = make_header(packet_type.DISCONNECT, 0, variable_header:len()) -- flags: 0
	return combine(header, variable_header)
end

-- Create AUTH packet, DOC: 3.15 AUTH – Authentication exchange
local function make_packet_auth(args)
	-- check args
	assert(type(args.rc) == "number", "expecting .rc to be a number")
	-- DOC: 3.15.2 AUTH Variable Header
	local variable_header = combine()
	-- DOC: The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Success) and there are no Properties. In this case the AUTH has a Remaining Length of 0.
	local props = make_properties(packet_type.AUTH, args)		-- DOC: 3.15.2.2 AUTH Properties
	if props:len() > 1 or args.rc ~= 0 then
		variable_header:append(make_uint8(args.rc))				-- DOC: 3.15.2.1 Authenticate Reason Code
		variable_header:append(props)							-- DOC: 3.15.2.2 AUTH Properties
	end
	-- DOC: 3.15.1 AUTH Fixed Header
	local header = make_header(packet_type.AUTH, 0, variable_header:len())
	return combine(header, variable_header)
end

-- Create packet of given {type: number} in args
function protocol5.make_packet(args)
	assert(type(args) == "table", "expecting args to be a table")
	assert(type(args.type) == "number", "expecting .type number in args")
	local ptype = args.type
	if ptype == packet_type.CONNECT then			-- 1
		return make_packet_connect(args)
	elseif ptype == packet_type.CONNACK then		-- 3
		return make_packet_connack(args)
	elseif ptype == packet_type.PUBLISH then		-- 3
		return make_packet_publish(args)
	elseif ptype == packet_type.PUBACK then			-- 4
		return make_packet_puback(args)
	elseif ptype == packet_type.PUBREC then			-- 5
		return make_packet_pubrec(args)
	elseif ptype == packet_type.PUBREL then			-- 6
		return make_packet_pubrel(args)
	elseif ptype == packet_type.PUBCOMP then		-- 7
		return make_packet_pubcomp(args)
	elseif ptype == packet_type.SUBSCRIBE then		-- 8
		return make_packet_subscribe(args)
	elseif ptype == packet_type.SUBACK then			-- 9
		return make_packet_suback(args)
	elseif ptype == packet_type.UNSUBSCRIBE then	-- 10
		return make_packet_unsubscribe(args)
	elseif ptype == packet_type.UNSUBACK then		-- 11
		return make_packet_unsuback(args)
	elseif ptype == packet_type.PINGREQ then		-- 12
		-- DOC: 3.12 PINGREQ – PING request
		return combine("\192\000") -- 192 == 0xC0, type == 12, flags == 0
	elseif ptype == packet_type.PINGRESP then		-- 12
		-- DOC: 3.13 PINGRESP – PING response
		return combine("\208\000") -- 208 == 0xD0, type == 13, flags == 0
	elseif ptype == packet_type.DISCONNECT then		-- 14
		return make_packet_disconnect(args)
	elseif ptype == packet_type.AUTH then			-- 15
		return make_packet_auth(args)
	else
		error("unexpected packet type to make: "..ptype)
	end
end

-- Parse properties using given read_data function for specified packet type
-- Result will be stored in packet.properties and packet.user_properties
-- Returns false plus string with error message on failure
-- Returns true on success
local function parse_properties(ptype, read_data, input, packet)
	assert(type(read_data) == "function", "expecting read_data to be a function")
	-- DOC: 2.2.2 Properties
	-- parse Property Length
	-- create read_func for parse_var_length and other parse functions, reading from data string instead of network connector
	local len, err = parse_var_length(read_data)
	if not len then
		return false, "failed to parse properties length: "..err
	end
	-- check data contains enough bytes for reading properties
	if input.available < len then
		return false, "not enough data to parse properties of length "..len
	end
	-- ensure properties and user_properties are presented in packet
	if not packet.properties then
		packet.properties = {}
	end
	if not packet.user_properties then
		packet.user_properties = {}
	end
	local uprops = packet.user_properties
	-- parse allowed properties
	local uprop_id = properties.user_property
	local allowed = assert(allowed_properties[ptype], "no allowed properties for specified packet type: "..tostring(ptype))
	local props_end = input[1] + len
	while input[1] < props_end do
		-- property id, DOC: 2.2.2.2 Property
		local prop_id
		prop_id, err = parse_var_length(read_data)
		if not prop_id then
			return false, "failed to parse property length: "..err
		end
		if not allowed[prop_id] then
			if not allowed[prop_id] then
				return false, "property "..tostring(properties[prop_id]).." ("..prop_id..") is not allowed for that packet type"
			end
		end
		if prop_id == uprop_id then
			-- parse name=value string pair
			local name, value
			name, err = parse_string(read_data)
			if not name then
				return false, "failed to parse user property name: "..err
			end
			value, err = parse_string(read_data)
			if not value then
				return false, "failed to parse user property value: "..err
			end
			local old_val = uprops[name]
			if old_val ~= nil then
				-- ensure uprops contains pairs with name = <old value>
				local found = false
				for _, pair in ipairs(uprops) do
					if pair[1] == name and pair[2] == old_val then
						found = true
						break
					end
				end
				if not found then
					uprops[#uprops + 1] = {name, old_val}
				end
				uprops[#uprops + 1] = {name, value}
			end
			uprops[name] = value
		else
			-- parse property value according its identifier
			local value
			value, err = property_parse[prop_id](read_data)
			if err then
				return false, "failed to parse property "..prop_id.." value: "..err
			end
			if allowed[prop_id] ~= true then
				if packet.properties[properties[prop_id]] ~= nil then
					return false, "it is a Protocol Error to include the "..properties[prop_id].." ("..prop_id..") property more than once"
				end
			end
			-- make an array of property values, if it's allowed to send multiple such properties
			if property_multiple[prop_id] then
				local curr = packet.properties[properties[prop_id]] or {}
				curr[#curr + 1] = value
				packet.properties[properties[prop_id]] = curr
			else
				packet.properties[properties[prop_id]] = value
			end
		end
	end
	return true
end

-- Parse CONNACK packet, DOC: 3.2 CONNACK – Connect acknowledgement
local function parse_packet_connack(ptype, flags, input)
	-- DOC: 3.2.1 CONNACK Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	if input.available < 3 then
		return false, packet_type[ptype]..": expecting data of length 3 bytes or more"
	end
	local read_data = input.read_func
	-- DOC: 3.2.2 CONNACK Variable Header
	-- DOC: 3.2.2.1.1 Session Present
	-- DOC: 3.2.2.2 Connect Reason Code
	local byte1, byte2 = parse_uint8(read_data), parse_uint8(read_data)
	local sp = (band(byte1, 0x1) ~= 0)
	local packet = setmetatable({type=ptype, sp=sp, rc=byte2}, connack_packet_mt)
	-- DOC: 3.2.2.3 CONNACK Properties
	local ok, err = parse_properties(ptype, read_data, input, packet)
	if not ok then
		return false, packet_type[ptype]..": failed to parse packet properties: "..err
	end
	return packet
end

-- Parse PUBLISH packet, DOC: 3.3 PUBLISH – Publish message
local function parse_packet_publish(ptype, flags, input)
	-- DOC: 3.3.1 PUBLISH Fixed Header
	-- DOC: 3.3.1.1 DUP
	local dup = (band(flags, 0x8) ~= 0)
	-- DOC: 3.3.1.2 QoS
	local qos = band(rshift(flags, 1), 0x3)
	-- DOC: 3.3.1.3 RETAIN
	local retain = (band(flags, 0x1) ~= 0)
	-- DOC: 3.3.2 PUBLISH Variable Header
	-- DOC: 3.3.2.1 Topic Name
	local read_data = input.read_func
	local topic, err = parse_string(read_data)
	if not topic then
		return false, packet_type[ptype]..": failed to parse topic: "..err
	end
	-- DOC: 3.3.2.2 Packet Identifier
	local packet_id, ok
	if qos > 0 then
		packet_id, err = parse_uint16(read_data)
		if not packet_id then
			return false, packet_type[ptype]..": failed to parse packet_id: "..err
		end
	end
	-- DOC: 3.3.2.3 PUBLISH Properties
	local packet = setmetatable({type=ptype, dup=dup, qos=qos, retain=retain, packet_id=packet_id, topic=topic}, packet_mt)
	ok, err = parse_properties(ptype, read_data, input, packet)
	if not ok then
		return false, packet_type[ptype]..": failed to parse packet properties: "..err
	end
	if input.available > 0 then
		-- DOC: 3.3.3 PUBLISH Payload
		packet.payload = read_data(input.available)
	end
	return packet
end

-- Parse PUBACK packet, DOC: 3.4 PUBACK – Publish acknowledgement
local function parse_packet_puback(ptype, flags, input)
	-- DOC: 3.4.1 PUBACK Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.4.2 PUBACK Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	local packet = setmetatable({type=ptype, packet_id=packet_id, rc=0, properties={}, user_properties={}}, packet_mt)
	if input.available > 0 then
		-- DOC: 3.4.2.1 PUBACK Reason Code
		local rc, ok
		rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse rc: "..err
		end
		packet.rc = rc
		-- DOC: 3.4.2.2 PUBACK Properties
		ok, err = parse_properties(ptype, read_data, input, packet)
		if not ok then
			return false, packet_type[ptype]..": failed to parse packet properties: "..err
		end
	end
	return packet
end

-- Parse PUBREC packet, DOC: 3.5 PUBREC – Publish received (QoS 2 delivery part 1)
local function parse_packet_pubrec(ptype, flags, input)
	-- DOC: 3.5.1 PUBREC Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.5.2 PUBREC Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	local packet = setmetatable({type=ptype, packet_id=packet_id, rc=0, properties={}, user_properties={}}, packet_mt)
	if input.available > 0 then
		-- DOC: 3.5.2.1 PUBREC Reason Code
		local rc
		rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse rc: "..err
		end
		packet.rc = rc
		-- DOC: 3.5.2.2 PUBREC Properties
		local ok
		ok, err = parse_properties(ptype, read_data, input, packet)
		if not ok then
			return false, packet_type[ptype]..": failed to parse packet properties: "..err
		end
	end
	return packet
end

-- Parse PUBREL packet, DOC: 3.6 PUBREL – Publish release (QoS 2 delivery part 2)
local function parse_packet_pubrel(ptype, flags, input)
	-- DOC: 3.6.1 PUBREL Fixed Header
	if flags ~= 2 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.6.2 PUBREL Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	local packet = setmetatable({type=ptype, packet_id=packet_id, rc=0, properties={}, user_properties={}}, packet_mt)
	if input.available > 0 then
		-- DOC: 3.6.2.1 PUBREL Reason Code
		local rc
		rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse rc: "..err
		end
		packet.rc = rc
		-- DOC: 3.6.2.2 PUBREL Properties
		local ok
		ok, err = parse_properties(ptype, read_data, input, packet)
		if not ok then
			return false, packet_type[ptype]..": failed to parse packet properties: "..err
		end
	end
	return packet
end

-- Parse PUBCOMP packet, DOC: 3.7 PUBCOMP – Publish complete (QoS 2 delivery part 3)
local function parse_packet_pubcomp(ptype, flags, input)
	-- DOC: 3.7.1 PUBCOMP Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.7.2 PUBCOMP Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	local packet = setmetatable({type=ptype, packet_id=packet_id, rc=0, properties={}, user_properties={}}, packet_mt)
	if input.available > 0 then
		-- DOC: 3.7.2.1 PUBCOMP Reason Code
		local rc
		rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse rc: "..err
		end
		packet.rc = rc
		-- DOC: 3.7.2.2 PUBCOMP Properties
		local ok
		ok, err = parse_properties(ptype, read_data, input, packet)
		if not ok then
			return false, packet_type[ptype]..": failed to parse packet properties: "..err
		end
	end
	return packet
end

-- Parse SUBSCRIBE packet, DOC: 3.8 SUBSCRIBE - Subscribe request
local function parse_packet_subscribe(ptype, flags, input)
	-- DOC: 3.8.1 SUBSCRIBE Fixed Header
	if flags ~= 2 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.8.2 SUBSCRIBE Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	local packet = setmetatable({type=ptype, packet_id=packet_id, properties={}, user_properties={}}, packet_mt)
	-- DOC: 3.8.2.1 SUBSCRIBE Properties
	local ok
	ok, err = parse_properties(ptype, read_data, input, packet)
	if not ok then
		return false, packet_type[ptype]..": failed to parse packet properties: "..err
	end
	-- DOC: 3.8.3 SUBSCRIBE Payload
	if input.available == 0 then
		-- DOC: A SUBSCRIBE packet with no Payload is a Protocol Error.
		return false, packet_type[ptype]..": empty subscriptions list"
	end
	local subscriptions = {}
	while input.available > 0 do
		local topic_filter
		topic_filter, err = parse_string(input.read_func)
		if not topic_filter then
			return false, packet_type[ptype]..": failed to parse SUBSCRIBE topic filter: "..err
		end
		-- DOC: 3.8.3.1 Subscription Options
		local subscription_options
		subscription_options, err = parse_uint8(input.read_func)
		if not subscription_options then
			return false, packet_type[ptype]..": failed to parse subscription_options: "..err
		end
		subscriptions[#subscriptions + 1] = {
			topic = topic_filter,
			qos = band(subscription_options, 0x3),
			no_local = band(subscription_options, 0x4) ~= 0,
			retain_as_published = band(subscription_options, 0x8) ~= 0, -- Retain As Published
			retain_handling = band(rshift(subscription_options, 4), 0x3), -- Retain Handling
		}
	end
	packet.subscriptions = subscriptions
	return packet
end

-- SUBACK return codes/reason code strings
-- DOC: Table 3‑8 - Subscribe Reason Codes
local suback_rc = {
	[0x00] = "Granted QoS 0",
	[0x01] = "Granted QoS 1",
	[0x02] = "Granted QoS 2",
	[0x80] = "Unspecified error",
	[0x83] = "Implementation specific error",
	[0x87] = "Not authorized",
	[0x8F] = "Topic Filter invalid",
	[0x91] = "Packet Identifier in use",
	[0x97] = "Quota exceeded",
	[0x9E] = "Shared Subscriptions not supported",
	[0xA1] = "Subscription Identifiers not supported",
	[0xA2] = "Wildcard Subscriptions not supported",
}
protocol5.suback_rc = suback_rc

--- Parsed SUBACK packet metatable
local suback_packet_mt = {
	__tostring = protocol.packet_tostring, -- packet-to-human-readable-string conversion metamethod using protocol.packet_tostring()
	reason_strings = function(self) -- Returns reason strings for the SUBACK packet according to its rc field
		local human_readable = {}
		for i, rc in ipairs(self.rc) do
			local reason_string = suback_rc[rc]
			if reason_string then
				human_readable[i] = reason_string
			else
				human_readable[i] = "Unknown: "..tostring(rc)
			end
		end
		return human_readable
	end,
}
suback_packet_mt.__index = suback_packet_mt
protocol5.suback_packet_mt = suback_packet_mt

-- Parse SUBACK packet, DOC: 3.9 SUBACK – Subscribe acknowledgement
local function parse_packet_suback(ptype, flags, input)
	-- DOC: 3.9.1 SUBACK Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.9.2 SUBACK Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	-- DOC: 3.9.2.1 SUBACK Properties
	local packet = setmetatable({type=ptype, packet_id=packet_id}, suback_packet_mt)
	local ok
	ok, err = parse_properties(ptype, read_data, input, packet)
	if not ok then
		return false, packet_type[ptype]..": failed to parse packet properties: "..err
	end
	-- DOC: 3.9.3 SUBACK Payload
	local rcs = {}
	while input.available > 0 do
		local rc
		rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse reason code: "..err
		end
		rcs[#rcs + 1] = rc
	end
	if not next(rcs) then
		return false, packet_type[ptype]..": expecting at least one reason code"
	end
	packet.rc = rcs
	return packet
end

-- Parse UNSUBSCRIBE packet, DOC: 3.10 UNSUBSCRIBE – Unsubscribe request
local function parse_packet_unsubscribe(ptype, flags, input)
	-- DOC: 3.10.1 UNSUBSCRIBE Fixed Header
	if flags ~= 2 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.10.2 UNSUBSCRIBE Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	local packet = setmetatable({type=ptype, packet_id=packet_id, properties={}, user_properties={}}, packet_mt)
	-- DOC: 3.10.2.1 UNSUBSCRIBE Properties
	local ok
	ok, err = parse_properties(ptype, read_data, input, packet)
	if not ok then
		return false, packet_type[ptype]..": failed to parse packet properties: "..err
	end
	-- 3.10.3 UNSUBSCRIBE Payload
	-- DOC: An UNSUBSCRIBE packet with no Payload is a Protocol Error.
	if input.available == 0 then
		return false, packet_type[ptype]..": empty subscriptions list"
	end
	local subscriptions = {}
	while input.available > 0 do
		local topic_filter
		topic_filter, err = parse_string(input.read_func)
		if not topic_filter then
			return false, packet_type[ptype]..": failed to parse topic filter: "..err
		end
		subscriptions[#subscriptions + 1] = topic_filter
	end
	packet.subscriptions = subscriptions
	return packet
end

-- UNSUBACK Reason Codes
-- DOC[2]: Table 3‑9 - Unsubscribe Reason Codes
local unsuback_rc = {
	[0x00] = "Success",
	[0x11] = "No subscription existed",
	[0x80] = "Unspecified error",
	[0x83] = "Implementation specific error",
	[0x87] = "Not authorized",
	[0x8F] = "Topic Filter invalid",
	[0x91] = "Packet Identifier in use",
}
protocol5.unsuback_rc = unsuback_rc

--- Parsed UNSUBACK packet metatable
local unsuback_packet_mt = {
	__tostring = protocol.packet_tostring, -- packet-to-human-readable-string conversion metamethod using protocol.packet_tostring()
	reason_strings = function(self) -- Returns reason strings for the UNSUBACK packet according to its rc field
		local human_readable = {}
		for i, rc in ipairs(self.rc) do
			local reason_string = unsuback_rc[rc]
			if reason_string then
				human_readable[i] = reason_string
			else
				human_readable[i] = "Unknown: "..tostring(rc)
			end
		end
		return human_readable
	end,
}
unsuback_packet_mt.__index = unsuback_packet_mt
protocol5.unsuback_packet_mt = unsuback_packet_mt

-- Parse UNSUBACK packet, DOC: 3.11 UNSUBACK – Unsubscribe acknowledgement
local function parse_packet_unsuback(ptype, flags, input)
	-- DOC: 3.11.1 UNSUBACK Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.11.2 UNSUBACK Variable Header
	local packet_id, err = parse_uint16(read_data)
	if not packet_id then
		return false, packet_type[ptype]..": failed to parse packet_id: "..err
	end
	-- 3.11.2.1 UNSUBACK Properties
	local packet = setmetatable({type=ptype, packet_id=packet_id}, unsuback_packet_mt)
	local ok
	ok, err = parse_properties(ptype, read_data, input, packet)
	if not ok then
		return false, packet_type[ptype]..": failed to parse packet properties: "..err
	end
	-- 3.11.3 UNSUBACK Payload
	local rcs = {}
	while input.available > 0 do
		local rc
		rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse reason code: "..err
		end
		rcs[#rcs + 1] = rc
	end
	if not next(rcs) then
		return false, packet_type[ptype]..": expecting at least one reason code in"
	end
	packet.rc = rcs
	return packet
end

-- Parse PINGREQ packet, DOC: 3.12 PINGREQ – PING request
local function parse_packet_pingreq(ptype, flags, _)
	-- DOC: 3.12.1 PINGREQ Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	return setmetatable({type=ptype, properties={}, user_properties={}}, packet_mt)
end

-- Parse PINGRESP packet, DOC: 3.13 PINGRESP – PING response
local function parse_packet_pingresp(ptype, flags, _)
	-- DOC: 3.13.1 PINGRESP Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	return setmetatable({type=ptype, properties={}, user_properties={}}, packet_mt)
end

-- DISCONNECT reason codes
-- DOC: Table 3‑10 – Disconnect Reason Code values
local disconnect_rc = {
	[0x00] = "Normal disconnection",
	[0x04] = "Disconnect with Will Message",
	[0x80] = "Unspecified error",
	[0x81] = "Malformed Packet",
	[0x82] = "Protocol Error",
	[0x83] = "Implementation specific error",
	[0x87] = "Not authorized",
	[0x89] = "Server busy",
	[0x8B] = "Server shutting down",
	[0x8D] = "Keep Alive timeout",
	[0x8E] = "Session taken over",
	[0x8F] = "Topic Filter invalid",
	[0x90] = "Topic Name invalid",
	[0x93] = "Receive Maximum exceeded",
	[0x94] = "Topic Alias invalid",
	[0x95] = "Packet too large",
	[0x96] = "Message rate too high",
	[0x97] = "Quota exceeded",
	[0x98] = "Administrative action",
	[0x99] = "Payload format invalid",
	[0x9A] = "Retain not supported",
	[0x9B] = "QoS not supported",
	[0x9C] = "Use another server",
	[0x9D] = "Server moved",
	[0x9E] = "Shared Subscriptions not supported",
	[0x9F] = "Connection rate exceeded",
	[0xA0] = "Maximum connect time",
	[0xA1] = "Subscription Identifiers not supported",
	[0xA2] = "Wildcard Subscriptions not supported",
}
protocol5.disconnect_rc = disconnect_rc

--- Parsed DISCONNECT packet metatable
local disconnect_packet_mt = {
	__tostring = protocol.packet_tostring, -- packet-to-human-readable-string conversion metamethod using protocol.packet_tostring()
	reason_string = function(self) -- Returns reason string for the DISCONNECT packet according to its rc field
		local reason_string = disconnect_rc[self.rc]
		if not reason_string then
			reason_string = "Unknown: "..self.rc
		end
		return reason_string
	end,
}
disconnect_packet_mt.__index = disconnect_packet_mt
protocol5.disconnect_packet_mt = disconnect_packet_mt

-- Parse DISCONNECT packet, DOC: 3.14 DISCONNECT – Disconnect notification
local function parse_packet_disconnect(ptype, flags, input)
	-- DOC: 3.14.1 DISCONNECT Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	local packet = setmetatable({type=ptype, rc=0, properties={}, user_properties={}}, disconnect_packet_mt)
	if input.available > 0 then
		-- DOC: 3.14.2 DISCONNECT Variable Header
		-- DOC: 3.14.2.1 Disconnect Reason Code
		local rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse rc: "..err
		end
		packet.rc = rc
		-- DOC: 3.14.2.2 DISCONNECT Properties
		local ok
		ok, err = parse_properties(ptype, read_data, input, packet)
		if not ok then
			return false, packet_type[ptype]..": failed to parse packet properties: "..err
		end
	end
	return packet
end

-- Parse AUTH packet, DOC: 3.15 AUTH – Authentication exchange
local function parse_packet_auth(ptype, flags, input)
	-- DOC: 3.15.1 AUTH Fixed Header
	if flags ~= 0 then -- Reserved
		return false, packet_type[ptype]..": unexpected flags value: "..flags
	end
	local read_data = input.read_func
	-- DOC: 3.15.2.1 Authenticate Reason Code
	local packet = setmetatable({type=ptype, rc=0, properties={}, user_properties={}}, packet_mt)
	if input.available > 1 then
		-- DOC: 3.15.2 AUTH Variable Header
		local rc, err = parse_uint8(read_data)
		if not rc then
			return false, packet_type[ptype]..": failed to parse Authenticate Reason Code: "..err
		end
		packet.rc = rc
		-- DOC: 3.15.2.2 AUTH Properties
		local ok
		ok, err = parse_properties(ptype, read_data, input, packet)
		if not ok then
			return false, packet_type[ptype]..": failed to parse packet properties: "..err
		end
	end
	return packet
end

-- Parse packet using given read_func
-- Returns packet on success or false and error message on failure
function protocol5.parse_packet(read_func)
	local ptype, flags, input = start_parse_packet(read_func)
	if not ptype then
		return false, flags
	end
	local packet, err

	-- parse read data according type in fixed header
	if ptype == packet_type.CONNECT then			-- 1
		packet, err = parse_packet_connect_input(input, const_v50)
	elseif ptype == packet_type.CONNACK then		-- 2
		packet, err = parse_packet_connack(ptype, flags, input)
	elseif ptype == packet_type.PUBLISH then		-- 3
		packet, err = parse_packet_publish(ptype, flags, input)
	elseif ptype == packet_type.PUBACK then			-- 4
		packet, err = parse_packet_puback(ptype, flags, input)
	elseif ptype == packet_type.PUBREC then			-- 5
		packet, err = parse_packet_pubrec(ptype, flags, input)
	elseif ptype == packet_type.PUBREL then			-- 6
		packet, err = parse_packet_pubrel(ptype, flags, input)
	elseif ptype == packet_type.PUBCOMP then		-- 7
		packet, err = parse_packet_pubcomp(ptype, flags, input)
	elseif ptype == packet_type.SUBSCRIBE then		-- 8
		packet, err = parse_packet_subscribe(ptype, flags, input)
	elseif ptype == packet_type.SUBACK then			-- 9
		packet, err = parse_packet_suback(ptype, flags, input)
	elseif ptype == packet_type.UNSUBSCRIBE then	-- 10
		packet, err = parse_packet_unsubscribe(ptype, flags, input)
	elseif ptype == packet_type.UNSUBACK then		-- 11
		packet, err = parse_packet_unsuback(ptype, flags, input)
	elseif ptype == packet_type.PINGREQ then		-- 12
		packet, err = parse_packet_pingreq(ptype, flags, input)
	elseif ptype == packet_type.PINGRESP then		-- 13
		packet, err = parse_packet_pingresp(ptype, flags, input)
	elseif ptype == packet_type.DISCONNECT then		-- 14
		packet, err = parse_packet_disconnect(ptype, flags, input)
	elseif ptype == packet_type.AUTH then			-- 15
		packet, err = parse_packet_auth(ptype, flags, input)
	else
		return false, "unexpected packet type received: "..tostring(ptype)
	end
	if packet and input.available > 0 then
		return false, packet_type[ptype]..": extra data in remaining length left after packet parsing"
	end
	return packet, err
end

-- Continue parsing of the MQTT v5.0 CONNECT packet
-- Internally called from the protocol.parse_packet_connect_input() function
-- Returns packet on success or false and error message on failure
function protocol5._parse_packet_connect_continue(input, packet)
	local read_func = input.read_func
	local ok, client_id, err

	-- DOC: 3.1.2.11 CONNECT Properties
	ok, err = parse_properties(packet_type.CONNECT, read_func, input, packet)
	if not ok then
		return false, "CONNECT: failed to parse packet properties: "..err
	end

	-- DOC: 3.1.3 CONNECT Payload

	-- DOC: 3.1.3.1 Client Identifier (ClientID)
	client_id, err = parse_string(read_func)
	if not client_id then
		return false, "CONNECT: failed to parse client_id: "..err
	end
	packet.id = client_id

	local will = packet.will
	if will then
		-- DOC: 3.1.3.2 Will Properties
		ok, err = parse_properties("will", read_func, input, will)
		if not ok then
			return false, "CONNECT: failed to parse will message properties: "..err
		end

		-- DOC: 3.1.3.3 Will Topic
		local will_topic, will_payload
		will_topic, err = parse_string(read_func)
		if not will_topic then
			return false, "CONNECT: failed to parse will_topic: "..err
		end
		will.topic = will_topic

		-- DOC: 3.1.3.4 Will Payload
		will_payload, err = parse_string(read_func)
		if not will_payload then
			return false, "CONNECT: failed to parse will_payload: "..err
		end
		will.payload = will_payload
	end

	-- DOC: 3.1.3.5 User Name
	if packet.username then
		local username
		username, err = parse_string(read_func)
		if not username then
			return false, "CONNECT: failed to parse username: "..err
		end
		packet.username = username
	else
		packet.username = nil
	end

	-- DOC: 3.1.3.6 Password
	if packet.password then
		local password
		password, err = parse_string(read_func)
		if not password then
			return false, "CONNECT: failed to parse password: "..err
		end
		packet.password = password
	else
		packet.password = nil
	end

	return setmetatable(packet, packet_mt)
end

-- export module table
return protocol5

-- vim: ts=4 sts=4 sw=4 noet ft=lua
