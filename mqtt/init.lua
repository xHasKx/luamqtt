--- MQTT module
-- @module mqtt
-- @usage
-- local client = mqtt.client {
-- 	uri = "mqtts://aladdin:soopersecret@mqttbroker.com",
-- 	clean = true,
-- 	version = mqtt.v50,	-- specify constant for MQTT version
-- }

--[[
MQTT protocol DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

CONVENTIONS:

	* errors:
		* passing invalid arguments (like number instead of string) to function in this library will raise exception
		* all other errors will be returned in format: false, "error-text"
			* you can wrap function call into standard lua assert() to raise exception

]]

--- Module table
-- @tfield number v311 MQTT v3.1.1 protocol version constant
-- @tfield number v50  MQTT v5.0   protocol version constant
-- @tfield string _VERSION luamqtt library version string
-- @table mqtt
local mqtt = {}

-- copy all values from const module
local const = require("mqtt.const")
for key, value in pairs(const) do
	mqtt[key] = value
end

-- load required stuff
local log = require "mqtt.log"

local select = select
local require = require

local client = require("mqtt.client")
local client_create = client.create

local ioloop = require("mqtt.ioloop")
local ioloop_get = ioloop.get

--- Create new MQTT client instance
-- @param ... Same as for `Client.create`(...)
-- @treturn Client new client instance
-- @see Client:__init
function mqtt.client(...)
	return client_create(...)
end

--- Returns default `ioloop` instance. Shortcut to `Ioloop.get`.
-- @function mqtt.get_ioloop
-- @see Ioloop.get
mqtt.get_ioloop = ioloop_get

--- Run default `ioloop` for given MQTT clients or functions.
-- Will not return until all clients/functions have exited.
-- @param ... MQTT clients or loop functions to add to ioloop, see `Ioloop:add` for details on functions.
-- @see Ioloop.get
-- @see Ioloop.run_until_clients
-- @usage
-- mqtt.run_ioloop(client1, client2, func1)
function mqtt.run_ioloop(...)
	log:info("starting default ioloop instance")
	local loop = ioloop_get()
	for i = 1, select("#", ...) do
		local cl = select(i, ...)
		loop:add(cl)
	end
	return loop:run_until_clients()
end


--- Validates a topic with wildcards.
-- @tparam string t wildcard-topic to validate
-- @treturn[1] string the input topic if valid
-- @treturn[2] boolean false if invalid
-- @treturn[2] string error description
-- @usage local t = assert(mqtt.validate_subscribe_topic("base/+/thermostat/#"))
function mqtt.validate_subscribe_topic(t)
	if type(t) ~= "string" then
		return false, "not a string"
	end
	if #t < 1 then
		return false, "minimum topic length is 1"
	end
	do
		local _, count = t:gsub("#", "")
		if count > 1 then
			return false, "wildcard '#' may only appear once"
		end
		if count == 1 then
			if t ~= "#" and not t:find("/#$") then
				return false, "wildcard '#' must be the last character, and be prefixed with '/' (unless the topic is '#')"
			end
		end
	end
	do
		local t1 = "/"..t.."/"
		local i = 1
		while i do
			i = t1:find("+", i)
			if i then
				if t1:sub(i-1, i+1) ~= "/+/" then
					return false, "wildcard '+' must be enclosed between '/' (except at start/end)"
				end
				i = i + 1
			end
		end
	end
	return t
end

--- Validates a topic without wildcards.
-- @tparam string t topic to validate
-- @treturn[1] string the input topic if valid
-- @treturn[2] boolean false if invalid
-- @treturn[2] string error description
-- @usage local t = assert(mqtt.validate_publish_topic("base/living/thermostat/setpoint"))
function mqtt.validate_publish_topic(t)
	if type(t) ~= "string" then
		return false, "not a string"
	end
	if #t < 1 then
		return false, "minimum topic length is 1"
	end
	if t:find("+", nil, true) or t:find("#", nil, true) then
		return false, "wildcards '#', and '+' are not allowed when publishing"
	end
	return t
end

--- Returns a Lua pattern from topic.
-- Takes a wildcarded-topic and returns a Lua pattern that can be used
-- to validate if a received topic matches the wildcard-topic
-- @tparam string t the wildcard topic
-- @treturn[1] string Lua-pattern that matches the topic and returns the captures
-- @treturn[2] boolean false if the topic was invalid
-- @treturn[2] string error description
-- @usage
-- local patt = compile_topic_pattern("homes/+/+/#")
--
-- local topic = "homes/myhome/living/mainlights/brightness"
-- local homeid, roomid, varargs = topic:match(patt)
function mqtt.compile_topic_pattern(t)
	local ok, err = mqtt.validate_subscribe_topic(t)
	if not ok then
		return ok, err
	end
	if t == "#" then
		t = "(.+)" -- matches anything at least 1 character long
	else
		-- first replace valid mqtt '+' and '#' with placeholders
		local hash = string.char(1)
		t = t:gsub("/#$", "/" .. hash)
		local plus = string.char(2)
		t = t:gsub("^%+$", plus)
		t = t:gsub("^%+/", plus .. "/")
		local c = 1
		while c ~= 0 do -- must loop, since adjacent patterns can overlap
			t, c = t:gsub("/%+/", "/" .. plus .. "/")
		end
		t = t:gsub("/%+$", "/" .. plus)

		-- now escape any special Lua pattern characters
		t = t:gsub("[%\\%(%)%.%%%+%-%*%?%[%^%$]", function(cap) return "%"..cap end)

		-- finally replace placeholders with captures
		t = t:gsub(hash,"(.-)")  -- match anything, can be empty
		t = t:gsub(plus,"([^/]-)") -- match anything between '/', can be empty
	end
	return "^"..t.."$"
end

--- Parses wildcards in a topic into a table.
-- @tparam string topic incoming topic string
-- @tparam table opts parsing options table
-- @tparam string opts.topic the wild-carded topic to match against (optional if `opts.pattern` is given)
-- @tparam string opts.pattern the compiled pattern for the wild-carded topic (optional if `opts.topic`
--   is given). If not given then topic will be compiled and the result will be
--   stored in this field for future use (cache).
-- @tparam array opts.keys array of field names. The order must be the same as the
--   order of the wildcards in `topic`
-- @treturn[1] table `fields`: the array part will have the values of the wildcards, in
--   the order they appeared. The hash part, will have the field names provided
--   in `opts.keys`, with the values of the corresponding wildcard. If a `#`
--   wildcard was used, that one will be the last in the table.
-- @treturn[1] `varargs`: The returned table is an array, with all segments that were
--   matched by the `#` wildcard (empty if there was no `#` wildcard).
-- @treturn[2] boolean `false` if there was no match
-- @return[3] `false`+err on error, eg. pattern was invalid.
-- @usage
-- local opts = {
--   topic = "homes/+/+/#",
--   keys = { "homeid", "roomid", "varargs"},
-- }
-- local fields, varargst = topic_match("homes/myhome/living/mainlights/brightness", opts)
--
-- print(fields[1], fields.homeid)  -- "myhome myhome"
-- print(fields[2], fields.roomid)  -- "living living"
-- print(fields[3], fields.varargs) -- "mainlights/brightness mainlights/brightness"
--
-- print(varargst[1]) -- "mainlights"
-- print(varargst[2]) -- "brightness"
function mqtt.topic_match(topic, opts)
	if type(topic) ~= "string" then
		return false, "expected topic to be a string"
	end
	if type(opts) ~= "table" then
		return false, "expected options to be a table"
	end
	local pattern = opts.pattern
	if not pattern then
		local ptopic = opts.topic
		if not ptopic then
			return false, "either 'opts.topic' or 'opts.pattern' must set"
		end
		local err
		pattern, err = mqtt.compile_topic_pattern(ptopic)
		if not pattern then
			return false, "failed to compile 'opts.topic' into pattern: "..tostring(err)
		end
		-- store/cache compiled pattern for next time
		opts.pattern = pattern
	end
	local values = { topic:match(pattern) }
	if values[1] == nil then
		return false
	end
	local keys = opts.keys
	if keys ~= nil then
		if type(keys) ~= "table" then
			return false, "expected 'opts.keys' to be a table (array)"
		end
		-- we have a table with keys, copy values to fields
		for i, value in ipairs(values) do
			local key = keys[i]
			if key ~= nil then
				values[key] = value
			end
		end
	end
	if not pattern:find("%(%.[%-%+]%)%$$") then -- pattern for "#" as last char
		-- we're done
		return values, {}
	end
	-- we have a '#' wildcard
	local vararg = values[#values]
	local varargs = {}
	local i = 0
	local ni = 0
	while ni do
		ni = vararg:find("/", i, true)
		if ni then
			varargs[#varargs + 1] = vararg:sub(i, ni-1)
			i = ni + 1
		else
			varargs[#varargs + 1] = vararg:sub(i, -1)
		end
	end

	return values, varargs
end


-- export module table
return mqtt

-- vim: ts=4 sts=4 sw=4 noet ft=lua
