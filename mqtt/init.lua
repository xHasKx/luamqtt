--- MQTT module
-- @module mqtt

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
-- @see mqtt.const
local mqtt = {}

-- copy all values from const module
local const = require("mqtt.const")
for key, value in pairs(const) do
	mqtt[key] = value
end

-- load required stuff
local type = type
local select = select
local require = require

local client = require("mqtt.client")
local client_create = client.create

local ioloop_get = require("mqtt.ioloop").get

--- Create new MQTT client instance
-- @param ... Same as for mqtt.client.create(...)
-- @see mqtt.client.client_mt:__init
function mqtt.client(...)
	return client_create(...)
end

--- Returns default ioloop instance
-- @function mqtt.get_ioloop
mqtt.get_ioloop = ioloop_get

--- Run default ioloop for given MQTT clients or functions
-- @param ... MQTT clients or lopp functions to add to ioloop
-- @see mqtt.ioloop.get
-- @see mqtt.ioloop.run_until_clients
function mqtt.run_ioloop(...)
	local loop = ioloop_get()
	for i = 1, select("#", ...) do
		local cl = select(i, ...)
		loop:add(cl)
		if type(cl) ~= "function" then
			cl:start_connecting()
		end
	end
	return loop:run_until_clients()
end

--- Run synchronous input/output loop for only one given MQTT client.
-- Provided client's connection will be opened.
-- Client reconnect feature will not work, and keep_alive too.
-- @param cl MQTT client instance to run
function mqtt.run_sync(cl)
	local ok, err = cl:start_connecting()
	if not ok then
		return false, err
	end
	while cl.connection do
		ok, err = cl:_sync_iteration()
		if not ok then
			return false, err
		end
	end
end


--- Validates a topic with wildcards.
-- @tparam string t wildcard topic to validate
-- @return topic, or false+error
-- @usage
-- local t = "invalid/#/subscribe/#/topic"
-- local topic = assert(mqtt.validate_subscribe_topic(t))
function mqtt.validate_subscribe_topic(t)
	if type(t) ~= "string" then
		return false, "bad subscribe-topic; expected topic to be a string, got: "..type(t)
	end
	if #t < 1 then
		return false, "bad subscribe-topic; expected minimum topic length of 1"
	end
	do
		local _, count = t:gsub("#", "")
		if count > 1 then
			return false, "bad subscribe-topic; wildcard '#' may only appear once, got: '"..t.."'"
		end
		if count == 1 then
			if t ~= "#" and not t:find("/#$") then
				return false, "bad subscribe-topic; wildcard '#' must be the last character, and " ..
				              "be prefixed with '/' (unless the topic is '#'), got: '"..t.."'"
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
					return false, "bad subscribe-topic; wildcard '+' must be enclosed between '/' " ..
					              "(except at start/end), got: '"..t.."'"
				end
				i = i + 1
			end
		end
	end
	return t
end

--- Validates a topic without wildcards.
-- @tparam string t topic to validate
-- @return topic, or false+error
-- @usage
-- local t = "invalid/#/publish/+/topic"
-- local topic = assert(mqtt.validate_publish_topic(t))
function mqtt.validate_publish_topic(t)
	if type(t) ~= "string" then
		return false, "bad publish-topic; expected topic to be a string, got: "..type(t)
	end
	if #t < 1 then
		return false, "bad publish-topic; expected minimum topic length of 1"
	end
	if t:find("+", nil, true) or t:find("#", nil, true) then
		return false, "bad publish-topic; wildcards '#', and '+' are not allowed when publishing, got: '"..t.."'"
	end
	return t
end

do
	local MATCH_ALL = "(.+)"     -- matches anything at least 1 character long
	local MATCH_HASH = "(.-)"    -- match anything, can be empty
	local MATCH_PLUS = "([^/]-)" -- match anything between '/', can be empty

	--- Returns a Lua pattern from topic.
	-- Takes a wildcarded-topic and returns a Lua pattern that can be used
	-- to validate if a received topic matches the wildcard-topic
	-- @tparam string t the wildcard topic
	-- @return Lua-pattern (string) or throws error on invalid input
	-- @usage
	-- local patt = compile_topic_pattern("homes/+/+/#")
	--
	-- local incoming_topic = "homes/myhome/living/mainlights/brightness"
	-- local homeid, roomid, varargs = incoming_topic:match(patt)
	function mqtt.compile_topic_pattern(t)
		t = assert(mqtt.validate_subscribe_topic(t))
		if t == "#" then
			t = MATCH_ALL
		else
			t = t:gsub("#", MATCH_HASH)
			t = t:gsub("%+", MATCH_PLUS)
		end
		return "^"..t.."$"
	end
end

do
	local HAS_VARARG_PATTERN = "%(%.[%-%+]%)%$$" -- matches patterns that have a vararg matcher

	--- Parses wildcards in a topic into a table.
	-- Options include:
	--
	-- - `opts.topic`: the wild-carded topic to match against (optional if `opts.pattern` is given)
	--
	-- - `opts.pattern`: the compiled pattern for the wild-carded topic (optional if `opts.topic`
	--   is given). If not given then topic will be compiled and the result will be
	--   stored in this field for future use (cache).
	--
	-- - `opts.keys`: (optional) array of field names. The order must be the same as the
	--   order of the wildcards in `topic`
	--
	-- Returned tables:
	--
	-- - `fields` table: the array part will have the values of the wildcards, in
	--   the order they appeared. The hash part, will have the field names provided
	--   in `opts.keys`, with the values of the corresponding wildcard. If a `#`
	--   wildcard was used, that one will be the last in the table.
	--
	-- - `varargs` table: will only be returned if the wildcard topic contained the
	--   `#` wildcard. The returned table is an array, with all segments that were
	--   matched by the `#` wildcard.
	-- @tparam string topic incoming topic string (required)
	-- @tparam table opts options table(required)
	-- @return fields (table) + varargs (table or nil), or false+err if the match failed,
	-- or throws an error on invalid input.
	-- @usage
	-- local opts = {
	--   topic = "homes/+/+/#",
	--   keys = { "homeid", "roomid", "varargs"},
	-- }
	-- local fields, varargs = topic_match("homes/myhome/living/mainlights/brightness", opts)
	--
	-- print(fields[1], fields.homeid)  -- "myhome myhome"
	-- print(fields[2], fields.roomid)  -- "living living"
	-- print(fields[3], fields.varargs) -- "mainlights/brightness mainlights/brightness"
	--
	-- print(varargs[1]) -- "mainlights"
	-- print(varargs[2]) -- "brightness"
	function mqtt.topic_match(topic, opts)
		if type(topic) ~= "string" then
			error("expected topic to be a string, got: "..type(topic))
		end
		if type(opts) ~= "table" then
			error("expected options to be a table, got: "..type(opts))
		end
		local pattern = opts.pattern
		if not pattern then
			local ptopic = assert(opts.topic, "either 'opts.topic' or 'opts.pattern' must set")
			pattern = assert(mqtt.compile_topic_pattern(ptopic))
			-- store/cache compiled pattern for next time
			opts.pattern = pattern
		end
		local values = { topic:match(pattern) }
		if values[1] == nil then
			return false, "topic does not match wildcard pattern"
		end
		local keys = opts.keys
		if keys ~= nil then
			if type(keys) ~= "table" then
				error("expected 'opts.keys' to be a table (array), got: "..type(keys))
			end
			-- we have a table with keys, copy values to fields
			for i, value in ipairs(values) do
				local key = keys[i]
				if key ~= nil then
					values[key] = value
				end
			end
		end
		if not pattern:find(HAS_VARARG_PATTERN) then -- pattern for "#" as last char
			-- we're done
			return values
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
end


-- export module table
return mqtt

-- vim: ts=4 sts=4 sw=4 noet ft=lua
