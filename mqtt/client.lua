--- MQTT client module
-- @module mqtt.client
-- @alias client
local client = {}

-- TODO: list event names

-------

-- load required stuff
local type = type
local error = error
local select = select
local require = require
local tostring = tostring

local os = require("os")
local os_time = os.time

local string = require("string")
local str_format = string.format
local str_gsub = string.gsub
local str_match = string.match

local table = require("table")
local table_remove = table.remove

local coroutine = require("coroutine")
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield

local math = require("math")
local math_random = math.random

local luamqtt_VERSION

local protocol = require("mqtt.protocol")
local packet_type = protocol.packet_type
local check_qos = protocol.check_qos
local next_packet_id = protocol.next_packet_id
local packet_id_required = protocol.packet_id_required

local protocol4 = require("mqtt.protocol4")
local make_packet4 = protocol4.make_packet
local parse_packet4 = protocol4.parse_packet

local protocol5 = require("mqtt.protocol5")
local make_packet5 = protocol5.make_packet
local parse_packet5 = protocol5.parse_packet

local ioloop = require("mqtt.ioloop")
local ioloop_get = ioloop.get

-------

--- MQTT client instance metatable
-- @type client_mt
local client_mt = {}
client_mt.__index = client_mt

--- Create and initialize MQTT client instance
-- @tparam table args							MQTT client creation arguments table
-- @tparam string args.uri						MQTT broker uri to connect.
--			Expecting "host:port" or "host" format, in second case the port will be selected automatically:
--			1883 port for plain or 8883 for secure network connections
-- @tparam boolean args.clean					clean session start flag
-- @tparam[opt=4] number args.version			MQTT protocol version to use, either 4 (for MQTT v3.1.1) or 5 (for MQTT v5.0).
--												Also you may use special values mqtt.v311 or mqtt.v50 for this field.
-- @tparam[opt] string args.id					MQTT client ID, will be generated by luamqtt library if absent
-- @tparam[opt] string args.username			username for authorization on MQTT broker
-- @tparam[opt] string args.password			password for authorization on MQTT broker; not acceptable in absence of username
-- @tparam[opt=false] boolean,table args.secure	use secure network connection, provided by luasec lua module;
--			set to true to select default params: { mode="client", protocol="tlsv1_2", verify="none", options="all" }
--			or set to luasec-compatible table, for example with cafile="...", certificate="...", key="..."
-- @tparam[opt] table args.will					will message table with required fields { topic="...", payload="..." }
--			and optional fields { qos=1...3, retain=true/false }
-- @tparam[opt=60] number args.keep_alive		time interval for client to send PINGREQ packets to the server when network connection is inactive
-- @tparam[opt=false] boolean args.reconnect	force created MQTT client to reconnect on connection close.
--			Set to number value to provide reconnect timeout in seconds
--			It's not recommended to use values < 3
-- @tparam[opt] table args.connector			connector table to open and send/receive packets over network connection.
--			default is require("mqtt.luasocket"), or require("mqtt.luasocket_ssl") if secure argument is set
-- @tparam[opt="ssl"] string args.ssl_module	module name for the luasec-compatible ssl module, default is "ssl"
--			may be used in some non-standard lua environments with own luasec-compatible ssl module
-- @treturn client_mt MQTT client instance table
function client_mt:__init(args)
	if not luamqtt_VERSION then
		luamqtt_VERSION = require("mqtt")._VERSION
	end

	-- fetch and validate client args
	local a = {} -- own client copy of args

	for key, value in pairs(args) do
		if type(key) ~= "string" then
			error("expecting string key in args, got: "..type(key))
		end

		local value_type = type(value)
		if key == "uri" then
			assert(value_type == "string", "expecting uri to be a string")
			a.uri = value
		elseif key == "clean" then
			assert(value_type == "boolean", "expecting clean to be a boolean")
			a.clean = value
		elseif key == "version" then
			assert(value_type == "number", "expecting version to be a number")
			assert(value == 4 or value == 5, "expecting version to be a value either 4 or 5")
			a.version = value
		elseif key == "id" then
			assert(value_type == "string", "expecting id to be a string")
			a.id = value
		elseif key == "username" then
			assert(value_type == "string", "expecting username to be a string")
			a.username = value
		elseif key == "password" then
			assert(value_type == "string", "expecting password to be a string")
			a.password = value
		elseif key == "secure" then
			assert(value_type == "boolean" or value_type == "table", "expecting secure to be a boolean or table")
			a.secure = value
		elseif key == "will" then
			assert(value_type == "table", "expecting will to be a table")
			a.will = value
		elseif key == "keep_alive" then
			assert(value_type == "number", "expecting keep_alive to be a number")
			a.keep_alive = value
		elseif key == "properties" then
			assert(value_type == "table", "expecting properties to be a table")
			a.properties = value
		elseif key == "user_properties" then
			assert(value_type == "table", "expecting user_properties to be a table")
			a.user_properties = value
		elseif key == "reconnect" then
			assert(value_type == "boolean" or value_type == "number", "expecting reconnect to be a boolean or number")
			a.reconnect = value
		elseif key == "connector" then
			a.connector = value
		elseif key == "ssl_module" then
			assert(value_type == "string", "expecting ssl_module to be a string")
			a.ssl_module = value
		else
			error("unexpected key in client args: "..key.." = "..tostring(value))
		end
	end

	-- check required arguments
	assert(a.uri, 'expecting uri="..." to create MQTT client')
	assert(a.clean ~= nil, "expecting clean=true or clean=false to create MQTT client")
	assert(not a.password or a.username, "password is not accepted in absence of username")

	if not a.id then
		-- generate random client id
		a.id = str_format("luamqtt-v%s-%07x", str_gsub(luamqtt_VERSION, "[^%d]", "-"), math_random(1, 0xFFFFFFF))
	end

	-- default connector
	if a.connector == nil then
		if a.secure then
			a.connector = require("mqtt.luasocket_ssl")
		else
			a.connector = require("mqtt.luasocket")
		end
	end
	-- validate connector content
	assert(type(a.connector) == "table", "expecting connector to be a table")
	assert(type(a.connector.connect) == "function", "expecting connector.connect to be a function")
	assert(type(a.connector.shutdown) == "function", "expecting connector.shutdown to be a function")
	assert(type(a.connector.send) == "function", "expecting connector.send to be a function")
	assert(type(a.connector.receive) == "function", "expecting connector.receive to be a function")

	-- will table content check
	if a.will then
		assert(type(a.will.topic) == "string", "expecting will.topic to be a string")
		assert(type(a.will.payload) == "string", "expecting will.payload to be a string")
		if a.will.qos ~= nil then
			assert(type(a.will.qos) == "number", "expecting will.qos to be a number")
			assert(check_qos(a.will.qos), "expecting will.qos to be a valid QoS value")
		end
		if a.will.retain ~= nil then
			assert(type(a.will.retain) == "boolean", "expecting will.retain to be a boolean")
		end
	end

	-- default keep_alive
	if not a.keep_alive then
		a.keep_alive = 60
	end

	-- client args
	self.args = a

	-- event handlers
	self.handlers = {
		connect = {},
		subscribe = {},
		unsubscribe = {},
		message = {},
		acknowledge = {},
		error = {},
		close = {},
		auth = {},
	}
	self._handling = {}
	self._to_remove_handlers = {}

	-- state
	self.first_connect = true		-- contains true to perform one network connection attempt after client creation
	self.send_time = 0				-- time of the last network send from client side

	-- packet creation/parse functions according version
	if not a.version then
		a.version = 4
	end
	if a.version == 4 then
		self._make_packet = make_packet4
		self._parse_packet = parse_packet4
	elseif a.version == 5 then
		self._make_packet = make_packet5
		self._parse_packet = parse_packet5
	end

	-- automatically add client to default ioloop, if it's available and running, then start connecting
	local loop = ioloop_get(false)
	if loop and loop.running then
		loop:add(self)
		self:start_connecting()
	end
end

--- Add functions as handlers of given events
-- @param ... (event_name, function) or { event1 = func1, event2 = func2 } table
function client_mt:on(...)
	local nargs = select("#", ...)
	local events
	if nargs == 2 then
		events = { [select(1, ...)] = select(2, ...) }
	elseif nargs == 1 then
		events = select(1, ...)
	else
		error("invalid args: expected only one or two arguments")
	end
	for event, func in pairs(events) do
		assert(type(event) == "string", "expecting event to be a string")
		assert(type(func) == "function", "expecting func to be a function")
		local handlers = self.handlers[event]
		if not handlers then
			error("invalid event '"..tostring(event).."' to handle")
		end
		handlers[#handlers + 1] = func
	end
end

-- Remove one item from the list-table with full-iteration
local function remove_item(list, item)
	for i, test in ipairs(list) do
		if test == item then
			table_remove(list, i)
			return
		end
	end
end

--- Remove given function handler for specified event
-- @tparam string event		event name to remove handler
-- @tparam function func	handler function to remove
function client_mt:off(event, func)
	local handlers = self.handlers[event]
	if not handlers then
		error("invalid event '"..tostring(event).."' to handle")
	end
	if self._handling[event] then
		-- this event is handling now, schedule the function removing to the moment after all handlers will be called for the event
		local to_remove = self._to_remove_handlers[event] or {}
		to_remove[#to_remove + 1] = func
		self._to_remove_handlers[event] = to_remove
	else
		-- it's ok to remove given function just now
		remove_item(handlers, func)
	end
	return true
end

--- Subscribe to specified topic. Returns the SUBSCRIBE packet id and calls optional callback when subscription will be created on broker
-- @tparam table args							subscription arguments
-- @tparam string args.topic					topic to subscribe
-- @tparam[opt=0] number args.qos				QoS level for subscription
-- @tparam boolean args.no_local				for MQTT v5.0 only: no_local flag for subscription
-- @tparam boolean args.retain_as_published		for MQTT v5.0 only: retain_as_published flag for subscription
-- @tparam boolean args.retain_handling			for MQTT v5.0 only: retain_handling flag for subscription
-- @tparam[opt] table args.properties			for MQTT v5.0 only: properties for subscribe operation
-- @tparam[opt] table args.user_properties		for MQTT v5.0 only: user properties for subscribe operation
-- @tparam[opt] function args.callback			callback function to be called when subscription will be created
-- @return packet id on success or false and error message on failure
function client_mt:subscribe(args)
	-- fetch and validate args
	assert(type(args) == "table", "expecting args to be a table")
	assert(type(args.topic) == "string", "expecting args.topic to be a string")
	assert(args.qos == nil or (type(args.qos) == "number" and check_qos(args.qos)), "expecting valid args.qos value")
	assert(args.no_local == nil or type(args.no_local) == "boolean", "expecting args.no_local to be a boolean")
	assert(args.retain_as_published == nil or type(args.retain_as_published) == "boolean", "expecting args.retain_as_published to be a boolean")
	assert(args.retain_handling == nil or type(args.retain_handling) == "boolean", "expecting args.retain_handling to be a boolean")
	assert(args.properties == nil or type(args.properties) == "table", "expecting args.properties to be a table")
	assert(args.user_properties == nil or type(args.user_properties) == "table", "expecting args.user_properties to be a table")
	assert(args.callback == nil or type(args.callback) == "function", "expecting args.callback to be a function")

	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	-- create SUBSCRIBE packet
	local pargs = {
		type = packet_type.SUBSCRIBE,
		subscriptions = {
			{
				topic = args.topic,
				qos = args.qos,
				no_local = args.no_local,
				retain_as_published = args.retain_as_published,
				retain_handling = args.retain_handling
			},
		},
		properties = args.properties,
		user_properties = args.user_properties,
	}
	self:_assign_packet_id(pargs)
	local packet_id = pargs.packet_id
	local subscribe = self._make_packet(pargs)

	-- send SUBSCRIBE packet
	local ok, err = self:_send_packet(subscribe)
	if not ok then
		err = "failed to send SUBSCRIBE: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	-- add subscribe callback
	local callback = args.callback
	if callback then
		local function handler(suback, ...)
			if suback.packet_id == packet_id then
				self:off("subscribe", handler)
				callback(suback, ...)
			end
		end
		self:on("subscribe", handler)
	end

	-- returns assigned packet id
	return packet_id
end

--- Unsubscribe from specified topic, and calls optional callback when subscription will be removed on broker
-- @tparam table args						subscription arguments
-- @tparam string args.topic				topic to unsubscribe
-- @tparam[opt] table args.properties		properties for unsubscribe operation
-- @tparam[opt] table args.user_properties	user properties for unsubscribe operation
-- @tparam[opt] function args.callback		callback function to be called when subscription will be removed on broker
-- @return packet id on success or false and error message on failure
function client_mt:unsubscribe(args)
	-- fetch and validate args
	assert(type(args) == "table", "expecting args to be a table")
	assert(type(args.topic) == "string", "expecting args.topic to be a string")
	assert(args.properties == nil or type(args.properties) == "table", "expecting args.properties to be a table")
	assert(args.user_properties == nil or type(args.user_properties) == "table", "expecting args.user_properties to be a table")
	assert(args.callback == nil or type(args.callback) == "function", "expecting args.callback to be a function")


	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	-- create UNSUBSCRIBE packet
	local  pargs = {
		type = packet_type.UNSUBSCRIBE,
		subscriptions = {args.topic},
		properties = args.properties,
		user_properties = args.user_properties,
	}
	self:_assign_packet_id(pargs)
	local packet_id = pargs.packet_id
	local unsubscribe = self._make_packet(pargs)

	-- send UNSUBSCRIBE packet
	local ok, err = self:_send_packet(unsubscribe)
	if not ok then
		err = "failed to send UNSUBSCRIBE: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	-- add unsubscribe callback
	local callback = args.callback
	if callback then
		local function handler(unsuback, ...)
			if unsuback.packet_id == packet_id then
				self:off("unsubscribe", handler)
				callback(unsuback, ...)
			end
		end
		self:on("unsubscribe", handler)
	end

	-- returns assigned packet id
	return packet_id
end

--- Publish message to broker
-- @tparam table args						publish operation arguments table
-- @tparam string args.topic				topic to publish message
-- @tparam[opt] string args.payload			publish message payload
-- @tparam[opt=0] number args.qos			QoS level for message publication
-- @tparam[opt=false] boolean args.retain	retain message publication flag
-- @tparam[opt=false] boolean args.dup		dup message publication flag
-- @tparam[opt] table args.properties		properties for publishing message
-- @tparam[opt] table args.user_properties	user properties for publishing message
-- @tparam[opt] function args.callback		callback to call when published message will be acknowledged
-- @return true or packet id on success or false and error message on failure
function client_mt:publish(args)
	-- fetch and validate args
	assert(type(args) == "table", "expecting args to be a table")
	assert(type(args.topic) == "string", "expecting args.topic to be a string")
	assert(args.payload == nil or type(args.payload) == "string", "expecting args.payload to be a string")
	assert(args.qos == nil or type(args.qos) == "number", "expecting args.qos to be a number")
	if args.qos then
		assert(check_qos(args.qos), "expecting qos to be a valid QoS value")
	end
	assert(args.retain == nil or type(args.retain) == "boolean", "expecting args.retain to be a boolean")
	assert(args.dup == nil or type(args.dup) == "boolean", "expecting args.dup to be a boolean")
	assert(args.properties == nil or type(args.properties) == "table", "expecting args.properties to be a table")
	assert(args.user_properties == nil or type(args.user_properties) == "table", "expecting args.user_properties to be a table")
	assert(args.callback == nil or type(args.callback) == "function", "expecting args.callback to be a function")

	-- check connection is alive
	local conn = self.connection
	if not conn then
		return false, "network connection is not opened"
	end

	-- create PUBLISH packet
	args.type = packet_type.PUBLISH
	self:_assign_packet_id(args)
	local packet_id = args.packet_id
	local publish = self._make_packet(args)

	-- send PUBLISH packet
	local ok, err = self:_send_packet(publish)
	if not ok then
		err = "failed to send PUBLISH: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	-- record packet id as waited for QoS 2 exchange
	if args.qos == 2 then
		conn.wait_for_pubrec[packet_id] = true
	end

	-- add acknowledge callback
	local callback = args.callback
	if callback then
		if packet_id then
			local function handler(ack, ...)
				if ack.packet_id == packet_id then
					self:off("acknowledge", handler)
					callback(ack, ...)
				end
			end
			self:on("acknowledge", handler)
		else
			callback("no ack for QoS 0 message", self)
		end
	end

	-- returns assigned packet id
	return packet_id or true
end

--- Acknowledge given received message
-- @tparam packet_mt msg				PUBLISH message to acknowledge
-- @tparam[opt=0] number rc				The reason code field of PUBACK packet in MQTT v5.0 protocol
-- @tparam[opt] table properties		properties for PUBACK/PUBREC packets
-- @tparam[opt] table user_properties	user properties for PUBACK/PUBREC packets
-- @return true on success or false and error message on failure
function client_mt:acknowledge(msg, rc, properties, user_properties)
	assert(type(msg) == "table" and msg.type == packet_type.PUBLISH, "expecting msg to be a publish packet")
	assert(rc == nil or type(rc) == "number", "expecting rc to be a number")
	assert(properties == nil or type(properties) == "table", "expecting properties to be a table")
	assert(user_properties == nil or type(user_properties) == "table", "expecting user_properties to be a table")

	-- check connection is alive
	local conn = self.connection
	if not conn then
		return false, "network connection is not opened"
	end

	-- check packet needs to be acknowledged
	local packet_id = msg.packet_id
	if not packet_id then
		return true
	end

	if msg.qos == 1 then
		-- PUBACK should be sent

		-- create PUBACK packet
		local puback = self._make_packet{
			type = packet_type.PUBACK,
			packet_id = packet_id,
			rc = rc or 0,
			properties = properties,
			user_properties = user_properties,
		}

		-- send PUBACK packet
		local ok, err = self:_send_packet(puback)
		if not ok then
			err = "failed to send PUBACK: "..err
			self:handle("error", err, self)
			self:close_connection("error")
			return false, err
		end
	elseif msg.qos == 2 then
		-- PUBREC should be sent and packet_id should be remembered for PUBREL+PUBCOMP sequence

		-- create PUBREC packet
		local pubrec = self._make_packet{
			type = packet_type.PUBREC,
			packet_id = packet_id,
			rc = rc or 0,
			properties = properties,
			user_properties = user_properties,
		}

		-- send PUBREC packet
		local ok, err = self:_send_packet(pubrec)
		if not ok then
			err = "failed to send PUBREC: "..err
			self:handle("error", err, self)
			self:close_connection("error")
			return false, err
		end

		-- store packet id as waiting for PUBREL
		conn.wait_for_pubrel[packet_id] = true
	end

	return true
end

--- Send DISCONNECT packet to the broker and close the connection
-- @tparam[opt=0] number rc				The Disconnect Reason Code value from MQTT v5.0 protocol
-- @tparam[opt] table properties		properties for PUBACK/PUBREC packets
-- @tparam[opt] table user_properties	user properties for PUBACK/PUBREC packets
-- @return true on success or false and error message on failure
function client_mt:disconnect(rc, properties, user_properties)
	-- validate args
	assert(rc == nil or type(rc) == "number", "expecting rc to be a number")
	assert(properties == nil or type(properties) == "table", "expecting properties to be a table")
	assert(user_properties == nil or type(user_properties) == "table", "expecting user_properties to be a table")

	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	-- create DISCONNECT packet
	local disconnect = self._make_packet{
		type = packet_type.DISCONNECT,
		rc = rc or 0,
		properties = properties,
		user_properties = user_properties,
	}

	-- send DISCONNECT packet
	local ok, err = self:_send_packet(disconnect)
	if not ok then
		err = "failed to send DISCONNECT: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	-- now close connection
	self:close_connection("connection closed by client")

	return true
end

--- Send AUTH packet to authenticate client on broker, in MQTT v5.0 protocol
-- @tparam[opt=0] number rc				Authenticate Reason Code
-- @tparam[opt] table properties		properties for PUBACK/PUBREC packets
-- @tparam[opt] table user_properties	user properties for PUBACK/PUBREC packets
-- @return true on success or false and error message on failure
function client_mt:auth(rc, properties, user_properties)
	-- validate args
	assert(rc == nil or type(rc) == "number", "expecting rc to be a number")
	assert(properties == nil or type(properties) == "table", "expecting properties to be a table")
	assert(user_properties == nil or type(user_properties) == "table", "expecting user_properties to be a table")
	assert(self.args.version == 5, "allowed only in MQTT v5.0 protocol")

	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	-- create AUTH packet
	local auth = self._make_packet{
		type = packet_type.AUTH,
		rc = rc or 0,
		properties = properties,
		user_properties = user_properties,
	}

	-- send AUTH packet
	local ok, err = self:_send_packet(auth)
	if not ok then
		err = "failed to send AUTH: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	return true
end

--- Immediately close established network connection, without graceful session finishing with DISCONNECT packet
-- @tparam[opt] string reason the reasong string of connection close
function client_mt:close_connection(reason)
	assert(not reason or type(reason) == "string", "expecting reason to be a string")
	local conn = self.connection
	if not conn then
		return true
	end

	local args = self.args
	args.connector.shutdown(conn)
	self.connection = nil
	conn.close_reason = reason or "unspecified"

	self:handle("close", conn, self)

	-- check connection is still closed (self.connection may be re-created in "close" handler)
	if not self.connection then
		-- remove from ioloop
		if self.ioloop and not args.reconnect then
			self.ioloop:remove(self)
		end
	end

	return true
end

--- Start connecting to broker
-- @return true on success or false and error message on failure
function client_mt:start_connecting()
	-- print("start connecting") -- debug
	-- open network connection
	local ok, err = self:open_connection()
	if not ok then
		return false, err
	end

	-- send CONNECT packet
	ok, err = self:send_connect()
	if not ok then
		return false, err
	end

	return true
end

--- Low-level methods
-- @section low-level

--- Send PINGREQ packet
-- @return true on success or false and error message on failure
function client_mt:send_pingreq()
	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	-- create PINGREQ packet
	local pingreq = self._make_packet{
		type = packet_type.PINGREQ,
	}

	-- send PINGREQ packet
	local ok, err = self:_send_packet(pingreq)
	if not ok then
		err = "failed to send PINGREQ: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	return true
end

--- Open network connection to the broker
-- @return true on success or false and error message on failure
function client_mt:open_connection()
	if self.connection then
		return true
	end

	local args = self.args
	local connector = assert(args.connector, "no connector configured in MQTT client")

	-- create connection table
	local conn = {
		uri = args.uri,
		wait_for_pubrec = {},	-- a table with packet_id of partially acknowledged sent packets in QoS 2 exchange process
		wait_for_pubrel = {},	-- a table with packet_id of partially acknowledged received packets in QoS 2 exchange process
	}
	client_mt._parse_uri(args, conn)
	client_mt._apply_secure(args, conn)

	-- perform connect
	local ok, err = connector.connect(conn)
	if not ok then
		err = "failed to open network connection: "..err
		self:handle("error", err, self)
		return false, err
	end

	-- assign connection
	self.connection = conn

	-- create receive function
	local receive = connector.receive
	self.connection.recv_func = function(size)
		return receive(conn, size)
	end

	self:_apply_network_timeout()

	return true
end

--- Send CONNECT packet into opened network connection
-- @return true on success or false and error message on failure
function client_mt:send_connect()
	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	local args = self.args

	-- create CONNECT packet
	local connect = self._make_packet{
		type = packet_type.CONNECT,
		id = args.id,
		clean = args.clean,
		username = args.username,
		password = args.password,
		will = args.will,
		keep_alive = args.keep_alive,
		properties = args.properties,
		user_properties = args.user_properties,
	}

	-- send CONNECT packet
	local ok, err = self:_send_packet(connect)
	if not ok then
		err = "failed to send CONNECT: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	-- reset last packet id
	self._last_packet_id = nil

	return true
end

-- Internal methods

-- Set or rest ioloop for MQTT client
function client_mt:set_ioloop(loop)
	self.ioloop = loop
	self:_apply_network_timeout()
end

-- Send PUBREL acknowledge packet - second phase of QoS 2 exchange
-- Returns true on success or false and error message on failure
function client_mt:acknowledge_pubrel(packet_id)
	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	-- create PUBREL packet
	local pubrel = self._make_packet{type=packet_type.PUBREL, packet_id=packet_id, rc=0}

	-- send PUBREL packet
	local ok, err = self:_send_packet(pubrel)
	if not ok then
		err = "failed to send PUBREL: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	return true
end

-- Send PUBCOMP acknowledge packet - last phase of QoS 2 exchange
-- Returns true on success or false and error message on failure
function client_mt:acknowledge_pubcomp(packet_id)
	-- check connection is alive
	if not self.connection then
		return false, "network connection is not opened"
	end

	-- create PUBCOMP packet
	local pubcomp = self._make_packet{type=packet_type.PUBCOMP, packet_id=packet_id, rc=0}

	-- send PUBCOMP packet
	local ok, err = self:_send_packet(pubcomp)
	if not ok then
		err = "failed to send PUBCOMP: "..err
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	return true
end

-- Call specified event handlers
function client_mt:handle(event, ...)
	local handlers = self.handlers[event]
	if not handlers then
		error("invalid event '"..tostring(event).."' to handle")
	end
	self._handling[event] = true -- protecting self.handlers[event] table from modifications by client_mt:off() when iterating
	for _, handler in ipairs(handlers) do
		handler(...)
	end
	self._handling[event] = nil

	-- process handlers removing, scheduled by client_mt:off()
	local to_remove = self._to_remove_handlers[event]
	if to_remove then
		for _, func in ipairs(to_remove) do
			remove_item(handlers, func)
		end
		self._to_remove_handlers[event] = nil
	end
end

-- Internal methods

-- Assign next packet id for given packet creation args
function client_mt:_assign_packet_id(pargs)
	if not pargs.packet_id then
		if packet_id_required(pargs) then
			self._last_packet_id = next_packet_id(self._last_packet_id)
			pargs.packet_id = self._last_packet_id
		end
	end
end

-- Receive packet function in sync mode
local function sync_recv(self)
	return true, self:_receive_packet()
end

-- Perform one input/output iteration, called by sync receiving loop
function client_mt:_sync_iteration()
	return self:_io_iteration(sync_recv)
end

-- Receive packet function - from ioloop's coroutine
local function ioloop_recv(self)
	return coroutine_resume(self.connection.coro)
end

-- Perform one input/output iteration, called by ioloop
function client_mt:_ioloop_iteration()
	-- working according state
	local loop = self.ioloop
	local args = self.args

	local conn = self.connection
	if conn then
		-- network connection opened
		-- perform packet receiving using ioloop receive function
		local ok, err
		if loop then
			ok, err = self:_io_iteration(ioloop_recv)
		else
			ok, err = self:_sync_iteration()
		end

		if ok then
			-- send PINGREQ if keep_alive interval is reached
			if os_time() - self.send_time >= args.keep_alive then
				self:send_pingreq()
			end
		end

		return ok, err
	else
		-- no connection - first connect, reconnect or remove from ioloop
		if self.first_connect then
			self.first_connect = false
			self:start_connecting()
		elseif args.reconnect then
			if args.reconnect == true then
				self:start_connecting()
			else
				-- reconnect in specified timeout
				if self.reconnect_timer_start then
					if os_time() - self.reconnect_timer_start >= args.reconnect then
						self.reconnect_timer_start = nil
						self:start_connecting()
					else
						if loop then
							loop:can_sleep()
						end
					end
				else
					self.reconnect_timer_start = os_time()
				end
			end
		else
			-- finish working with client
			if loop then
				loop:remove(self)
			end
		end
	end
end

-- Performing one IO iteration - receive next packet
function client_mt:_io_iteration(recv)
	local conn = self.connection

	-- first - try to receive packet
	local ok, packet, err = recv(self)
	-- print("received packet", ok, packet, err)

	-- check coroutine resume status
	if not ok then
		err = "failed to resume receive packet coroutine: "..tostring(packet)
		self:handle("error", err, self)
		self:close_connection("error")
		return false, err
	end

	-- check for communication error
	if packet == false then
		if err == "closed" then
			self:close_connection("connection closed by broker")
			return false, err
		else
			err = "failed to receive next packet: "..err
			self:handle("error", err, self)
			self:close_connection("error")
			return false, err
		end
	end

	-- check some packet received
	if packet ~= "timeout" and packet ~= "wantread" then
		if not conn.connack then
			-- expecting only CONNACK packet here
			if packet.type ~= packet_type.CONNACK then
				err = "expecting CONNACK but received "..packet.type
				self:handle("error", err, self)
				self:close_connection("error")
				return false, err
			end

			-- store connack packet in connection
			conn.connack = packet

			-- check CONNACK rc
			if packet.rc ~= 0 then
				err = str_format("CONNECT failed with CONNACK [rc=%d]: %s", packet.rc, packet:reason_string())
				self:handle("error", err, self, packet)
				self:handle("connect", packet, self)
				self:close_connection("connection failed")
				return false, err
			end

			-- fire connect event
			self:handle("connect", packet, self)
		else
			-- connection authorized, so process usual packets

			-- handle packet according its type
			local ptype = packet.type
			if ptype == packet_type.PINGRESP then -- luacheck: ignore
				-- PINGREQ answer, nothing to do
				-- TODO: break the connectin in absence of this packet in some timeout
			elseif ptype == packet_type.SUBACK then
				self:handle("subscribe", packet, self)
			elseif ptype == packet_type.UNSUBACK then
				self:handle("unsubscribe", packet, self)
			elseif ptype == packet_type.PUBLISH then
				-- check such packet is not waiting for pubrel acknowledge
				self:handle("message", packet, self)
			elseif ptype == packet_type.PUBACK then
				self:handle("acknowledge", packet, self)
			elseif ptype == packet_type.PUBREC then
				local packet_id = packet.packet_id
				if conn.wait_for_pubrec[packet_id] then
					conn.wait_for_pubrec[packet_id] = nil
					-- send PUBREL acknowledge
					if self:acknowledge_pubrel(packet_id) then
						-- and fire acknowledge event
						self:handle("acknowledge", packet, self)
					end
				end
			elseif ptype == packet_type.PUBREL then
				-- second phase of QoS 2 exchange - check we are already acknowledged such packet by PUBREL
				local packet_id = packet.packet_id
				if conn.wait_for_pubrel[packet_id] then
					-- remove packet from waiting for PUBREL packets table
					conn.wait_for_pubrel[packet_id] = nil
					-- send PUBCOMP acknowledge
					self:acknowledge_pubcomp(packet_id)
				end
			elseif ptype == packet_type.PUBCOMP then --luacheck: ignore
				-- last phase of QoS 2 exchange
				-- do nothing here
			elseif ptype == packet_type.DISCONNECT then
				self:close_connection("disconnect received from broker")
			elseif ptype == packet_type.AUTH then
				self:handle("auth", packet, self)
			-- else
			-- 	print("unhandled packet:", packet) -- debug
			end
		end
	end

	return true
end

-- Apply ioloop network timeout to already established connection (if any)
function client_mt:_apply_network_timeout()
	local conn = self.connection
	if conn then
		local loop = self.ioloop
		if loop then
			-- apply connection timeout
			self.args.connector.settimeout(conn, loop.args.timeout)

			-- connection packets receive loop coroutine
			conn.coro = coroutine_create(function()
				while true do
					local packet, err = self:_receive_packet()
					if not packet then
						return false, err
					else
						coroutine_yield(packet)
					end
				end
			end)

			-- replace connection recv_func with coroutine-based version
			local sync_recv_func = conn.recv_func
			conn.recv_func = function(...)
				while true do
					local data, err = sync_recv_func(...)
					if not data and (err == "timeout" or err == "wantread") then
						loop.timeouted = true
						coroutine_yield(err)
					else
						return data, err
					end
				end
			end
			conn.sync_recv_func = sync_recv_func
		else
			-- disable connection timeout
			self.args.connector.settimeout(conn, nil)

			-- replace back usual (blocking) connection recv_func
			if conn.sync_recv_func then
				conn.recv_func = conn.sync_recv_func
				conn.sync_recv_func = nil
			end
		end
	end
end

-- Fill given connection table with host and port according given args
function client_mt._parse_uri(args, conn)
	local host, port = str_match(args.uri, "^([^%s]+):(%d+)$")
	if not host then
		-- trying pattern without port
		host = assert(str_match(conn.uri, "^([^%s]+)$"), "invalid uri format: expecting at least host/ip in .uri")
	end
	if not port then
		if args.secure then
			port = 8883 -- default MQTT secure connection port
		else
			port = 1883 -- default MQTT connection port
		end
	else
		port = tonumber(port)
	end
	conn.host, conn.port = host, port
end

-- Creates the conn.secure_params table and its content according client creation args
function client_mt._apply_secure(args, conn)
	local secure = args.secure
	if secure then
		conn.secure = true
		if type(secure) == "table" then
			conn.secure_params = secure
		else
			conn.secure_params = {
				mode = "client",
				protocol = "tlsv1_2",
				verify = "none",
				options = "all",
			}
		end
		conn.ssl_module = args.ssl_module or "ssl"
	end
end

-- Send given packet to opened network connection
function client_mt:_send_packet(packet)
	local conn = self.connection
	if not conn then
		return false, "network connection is not opened"
	end
	local data = tostring(packet)
	local len = data:len()
	if len <= 0 then
		return false, "sending empty packet"
	end
	-- and send binary packet to network connection
	local i, err = 1
	local send = self.args.connector.send
	while i < len do
		i, err = send(conn, data, i)
		if not i then
			return false, "connector.send failed: "..err
		end
	end
	self.send_time = os_time()
	return true
end

-- Receive one packet from established network connection
function client_mt:_receive_packet()
	local conn = self.connection
	if not conn then
		return false, "network connection is not opened"
	end
	-- parse packet
	local packet, err = self._parse_packet(conn.recv_func)
	if not packet then
		return false, err
	end
	return packet
end

-- Represent MQTT client as string
function client_mt:__tostring()
	return str_format("mqtt.client{id=%q}", tostring(self.args.id))
end

-- Garbage collection handler
function client_mt:__gc()
	-- close network connection if it's available, without sending DISCONNECT packet
	if self.connection then
		self:close_connection("garbage")
	end
end

--- Exported functions
-- @section exported

--- Create, initialize and return new MQTT client instance
-- @param ... see arguments of client_mt:__init(args)
-- @see client_mt:__init
-- @treturn client_mt MQTT client instance
function client.create(...)
	local cl = setmetatable({}, client_mt)
	cl:__init(...)
	return cl
end

-------

-- export module table
return client

-- vim: ts=4 sts=4 sw=4 noet ft=lua
