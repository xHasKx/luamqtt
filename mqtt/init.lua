-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html


--[[

CONVENTIONS:

	* errors:
		* passing invalid arguments to function in this library will raise exception
		* all other errors will be returned in format: false, "error-text"
			* you can wrap function call into standard lua assert() to raise exception

]]

-- module table
local mqtt = {
	-- supported MQTT protocol versions
	protocol_version = {
		"3.1.1",
	},
	-- mqtt library version
	library_versoin = "1.2.0",
}


local require = require

-- required modules
local string = require("string")
local protocol = require("mqtt.protocol")


-- cache to locals
local setmetatable = setmetatable
local str_match = string.match
local str_format = string.format
local str_gsub = string.gsub
local tbl_remove = table.remove
local math_random = math.random
local math_randomseed = math.randomseed
local os_time = os.time
local packet_type = protocol.packet_type
local make_packet = protocol.make_packet
local parse_packet = protocol.parse_packet
local connack_return_code = protocol.connack_return_code
local next_packet_id = protocol.next_packet_id
local packet_id_required = protocol.packet_id_required
local packet_tostring = protocol.packet_tostring


-- Empty function to do nothing on MQTT client events
local empty_func = function() end


-- pseudo-random generator initialized flag
local random_initialized = false


-- MQTT Client metatable
local client_mt = {
	-- Initialize MQTT client with given args
	-- args: table with keys:
	-- 		id 			-- [optional] client id value for connecting to MQTT broker. Will be generated, if not provided
	-- 		uri 		-- [mandatory] MQTT broker URI to connect in format "host:port" or "host" (default port is 1883)
	-- 		ssl 		-- [optional] true to open SSL network connection
	-- 		clean 		-- [mandatory] clean session flag (true/false)
	-- 		auth 		-- [optional] table with username and password keys to authorize on MQTT broker
	-- 		debug 		-- [optional] debug function like print, will be called with mqtt client and message to show, default is nil (no debug output).
	-- 		connector 	-- [optional] table with network connection functions, default is mqtt/luasocket.lua built-in module.
	-- 					   You may implement your own table to work with network connections in your environment.
	init = function(self, args)
		-- assign properties
		self.id = args.id
		if self.id ~= nil then
			assert(type(self.id) == "string", "expecting .id to be a string")
		else
			-- auto-generate self.id
			if not random_initialized then
				-- initialize pseudo-random generator with current time seed
				math_randomseed(os_time())
				random_initialized = true
			end
			self.id = str_format("luamqtt-v%s-%07x", str_gsub(mqtt.library_versoin, "%.", "-"), math_random(1, 0xFFFFFFF))
		end
		self.uri = args.uri
		assert(type(self.uri) == "string", "expecting .uri to be a string")
		self.ssl = args.ssl
		if self.ssl ~= nil then
			assert(type(self.ssl) == "boolean" or type(self.ssl) == "table", "expecting .uri to be a boolean or table")
		end
		self.clean = args.clean
		assert(type(self.clean) == "boolean", "expecting .clean to be a boolean")
		self.auth = args.auth
		if self.auth ~= nil then
			assert(type(self.auth) == "table", "expecting .auth to be a table")
		end
		self.will = args.will
		if self.will ~= nil then
			assert(type(self.will) == "table", "expecting .will to be a table")
		end
		self.debug = args.debug
		self.connector = args.connector
		if not self.connector then
			-- fallback to default connector (built-in based on luasocket)
			if self.ssl then
				self.connector = require("mqtt.luasocket_ssl")
			else
				self.connector = require("mqtt.luasocket")
			end
		end
		-- available events of this client
		self.handlers = {
			connect = empty_func,
			message = empty_func,
			error = empty_func,
			close = empty_func,
		}
		self:_debug("initialized")
	end,

	-- Assign function as handler of given event
	-- Old function handler will be replaced (if any)
	on = function(self, event, func)
		assert(type(event) == "string", "expecting event to be a string")
		assert(type(func) == "function", "expecting func to be a function")
		assert(self.handlers[event], "invalid event to handle: "..event)
		self.handlers[event] = func
	end,

	-- Publish Application message to the broker
	-- args: table with keys:
	-- 		topic 		-- [mandatory] topic string to publish
	-- 		payload 	-- [optional] application message payload string
	-- 		qos 		-- [optional] QoS (0, 1 or 2), default is 0
	-- 		retain 		-- [optional] retain message flag, true or false
	publish = function(self, args)
		assert(type(args) == "table", "expecting args to be a table")
		-- copy args
		local acopy = {
			type = packet_type.PUBLISH,
		}
		for k, v in pairs(args) do
			acopy[k] = v
		end
		assert(type(acopy.topic) == "string", "expecting .topic to be a string")
		acopy.qos = acopy.qos or 0
		acopy.retain = acopy.retain or false
		if acopy.payload ~= nil then
			assert(type(acopy.payload) == "string", "expecting .payload to be a string")
		end
		acopy.dup = false
		local ok, err = self:_send_packet(acopy)
		if not ok then
			err = "PUBLISH send failed: "..err
			self.handlers.error(err)
			return false, err
		end
		-- check we need to wait for PUBACK
		if acopy.qos == 1 then -- TODO: QoS 2
			local puback, perr = self:_wait_packet_exact{type=packet_type.PUBACK, packet_id=acopy.packet_id}
			if not puback then
				perr = "PUBLISH wait for PUBACK failed: "..perr
				self.handlers.error(perr)
				return false, perr
			end
		end
		return true
	end,

	-- Send PUBACK packet for given msg packet, if need
	puback = function(self, msg)
		assert(type(msg) == "table", "expecting msg to be a table")
		if msg.qos == 0 then
			return true
		end
		assert(type(msg.packet_id) == "number", "expecting .packet_id to be a number")
		local ok, err = self:_send_packet{
			type = packet_type.PUBACK,
			packet_id = msg.packet_id,
		}
		if not ok then
			err = "PUBACK send failed: "..err
			self.handlers.error(err)
			return false, err
		end
		return true
	end,

	-- Subscribe to topics and qos-es in varargs as {topic="...", qos=X}-tables in varargs
	subscribe = function(self, ...)
		local args = {
			type = packet_type.SUBSCRIBE,
			subscriptions = {...},
		}
		local ok, err = self:_send_packet(args)
		if not ok then
			err = "SUBSCRIBE send failed: "..err
			self.handlers.error(err)
			return false, err
		end
		ok, err = self:_wait_packet_exact{type=packet_type.SUBACK, packet_id=args.packet_id}
		if not ok then
			err = "SUBSCRIBE wait for SUBACK failed: "..err
			self.handlers.error(err)
			return false, err
		end
		return true
	end,

	-- Unsubscribe from one or more topics as strings in varargs
	unsubscribe = function(self, ...)
		local args = {
			type = packet_type.UNSUBSCRIBE,
			subscriptions = {...},
		}
		local ok, err = self:_send_packet(args)
		if not ok then
			err = "UNSUBSCRIBE send failed: "..err
			self.handlers.error(err)
			return false, err
		end
		ok, err = self:_wait_packet_exact{type=packet_type.UNSUBACK, packet_id=args.packet_id}
		if not ok then
			err = "UNSUBSCRIBE wait for UNSUBACK failed: "..err
			self.handlers.error(err)
			return false, err
		end
		return true
	end,

	-- Close network connection without sending DISCONNECT packet
	close_connection = function(self)
		if self.connection then
			self:_debug("closing network connection")
			self.connector.shutdown(self.connection)
			self.connection = nil
			self.handlers.close()
		end
	end,

	-- Gracefully disconnect from MQTT broker.
	-- Send DISCONNECT packet and close network connection
	disconnect = function(self)
		if self.connection then
			self:_debug("disconnect from MQTT broker")
			self:_send_packet{type=packet_type.DISCONNECT}
			self:close_connection()
		end
	end,

	-- Connect to MQTT broker and run forever until network connection is available
	-- Returns true on success when connection was closed gracefully or false and error message on failure
	connect_and_run = function(self)
		-- open network connection to MQTT broker
		local ok, err = self:_open_connection()
		if not ok then
			err = "open network connection failed: "..err
			self.handlers.error(err)
			return false, err
		end
		ok, err = (function()
			-- send CONNECT packet
			local args = {
				type = packet_type.CONNECT,
				id = self.id,
				clean = self.clean,
			}
			if self.auth then
				args.username = self.auth.username
				args.password = self.auth.password
			end
			if self.will then
				args.will = {}
				for k, v in pairs(self.will) do
					args.will[k] = v
				end
				args.will.qos = args.will.qos or 0
				args.will.retain = args.will.retain or false
			end
			local sok, serr = self:_send_packet(args)
			if not sok then
				serr = "send CONNECT failed: "..serr
				self.handlers.error(serr)
				return false, serr
			end
			-- start packet receiving loop
			while self.connection do
				local packet, perr = self:_wait_packet_queue()
				if not packet then
					perr = "waiting for the next packet failed: "..perr
					self.handlers.error(perr)
					return false, perr
				end
				self:_debug("[run] received packet: %s", tostring(packet))
				if packet.type == packet_type.CONNACK then
					if packet.rc ~= 0 then
						perr = str_format("CONNECT failed with CONNACK rc=[%d] %s", packet.rc, tostring(connack_return_code[packet.rc]))
						self.handlers.error(perr)
						return false, perr
					end
					self.handlers.connect(packet)
				elseif packet.type == packet_type.PUBLISH then
					self.handlers.message(packet)
				-- elseif packet.type == packet_type.PUBACK then
					-- received acknowledge of some published packet
				else
					return false, "unexpected packet received: "..tostring(packet)
				end
			end
			return true
		end)()
		-- ensure network connection is closed
		self:close_connection()
		if not ok then
			return false, err
		end
		-- indicate graceful connection close
		return true
	end,

	-- Internal methods

	-- Open network connection to broker
	_open_connection = function(self)
		-- prepare network connection table
		local conn = {
			uri = self.uri,
			queue = {},
		}
		self:_parse_uri(conn)
		self:_set_ssl_params(conn)
		-- open TCP connection
		self:_debug("open_connection to %s", conn.uri)
		local ok, err = self.connector.connect(conn)
		if not ok then
			return false, err
		end
		self.connection = conn
		self:_debug("network connection established")
		return true
	end,

	-- Send packet to opened network connection
	-- Returns true on success or false and error message on failure
	_send_packet = function(self, args)
		if not self.connection then
			return false, "network connection is not opened"
		end
		-- assign next packet id, if packet is requiring it
		self:_assign_packet_id(args)
		self:_debug("send_packet: %s", packet_tostring(args))
		-- create binary packet
		local packet = make_packet(args)
		local data = tostring(packet)
		local len = data:len()
		if len <= 0 then
			return false, "sending empty packet"
		end
		-- and send binary packet to network connection
		local i, err = 1
		while i < len do
			i, err = self.connector.send(self.connection, data, i)
			if not i then
				err = "connector.send failed: "..err
				return false, err
			end
		end
		return true
	end,

	-- Wait for packet with properties equals to given args, queueing all other packets
	_wait_packet_exact = function(self, args)
		while true do
			-- receive next packet
			local packet, err = self:_wait_packet()
			if not packet then
				return false, err
			end
			self:_debug("[exact] received packet: %s", tostring(packet))
			-- check this packet match given args
			local match = true
			for k, v in pairs(args) do
				if packet[k] ~= v then
					match = false
					break
				end
			end
			if match then
				return packet
			end
			-- if not match - queue it for future processing
			self.connection.queue[#self.connection.queue + 1] = packet
		end
	end,

	-- Return and remove first packet in received queue or wait and receive the next packet
	_wait_packet_queue = function(self)
		if self.connection.queue[1] then
			-- remove already received packet from queue and return it
			return tbl_remove(self.connection.queue, 1)
		end
		return self:_wait_packet()
	end,

	-- Wait for the next packet and receive it from network connection
	_wait_packet = function(self)
		if not self.connection then
			return false, "network connection is not opened"
		end
		local recv_func = function(size)
			return self.connector.receive(self.connection, size)
		end
		-- parse packet
		local packet, err = parse_packet(recv_func)
		if not packet then
			return false, err
		end
		return packet
	end,

	-- Parse conn.uri to conn.host and conn.port to connect
	_parse_uri = function(self, conn)
		local host, port = str_match(conn.uri, "^([%w%.%-]+):(%d+)$")
		if not host then
			-- trying pattern without port
			host = assert(str_match(conn.uri, "^([%w%.%-]+)$"), "invalid uri format: expecting at least host/ip in .uri")
		end
		if not port then
			if self.ssl then
				port = 8883 -- default MQTT secure connection port
			else
				port = 1883 -- default MQTT connection port
			end
		end
		conn.host, conn.port = host, port
		self:_debug("host: %s, port: %s", host, port)
	end,

	-- Setup ssl params into connection
	_set_ssl_params = function(self, conn)
		if type(self.ssl) == "table" then
			conn.ssl_params = self.ssl
		else
			-- default ssl params
			conn.ssl_params = {
				mode = "client",
				protocol = "tlsv1_2",
				verify = "none",
				options = "all",
			}
		end
	end,

	-- Assign next packet ID to the args
	_assign_packet_id = function(self, args)
		if not args.packet_id then
			if packet_id_required(args) then
				self._last_packet_id = next_packet_id(self._last_packet_id)
				args.packet_id = self._last_packet_id
			end
		end
	end,

	-- Prints debug message
	_debug = function(self, msg, ...)
		if self.debug then
			self.debug(self, str_format(msg, ...))
		end
	end,

	-- Represent MQTT client as string
	__tostring = function(self)
		return str_format("mqtt.client{id=%q}", tostring(self.id))
	end,

	-- Garbage collection handler
	__gc = function(self)
		-- close network connection if it's available, without sending DISCONNECT packet
		if self.connection then
			self:close_connection()
		end
	end,
}

-- Make client_mt table works like a class
client_mt.__index = function(_, key)
	return client_mt[key]
end


-- module function to create MQTT client instance
function mqtt.client(args)
	local c = setmetatable({}, client_mt)
	c:init(args)
	return c
end

-- export module table
return mqtt

-- vim: ts=4 sts=4 sw=4 noet ft=lua
