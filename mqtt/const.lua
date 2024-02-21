--- MQTT const module

--- Module table
-- @tfield number v311 MQTT v3.1.1 protocol version constant
-- @tfield number v50  MQTT v5.0   protocol version constant
-- @tfield string _VERSION luamqtt library version string
-- @table const
local const = {
	-- supported MQTT protocol versions
	v311 = 4,		-- supported protocol version, MQTT v3.1.1
	v50 = 5,		-- supported protocol version, MQTT v5.0

	-- luamqtt library version string
	_VERSION = "3.4.3",
}

return const

-- vim: ts=4 sts=4 sw=4 noet ft=lua
