package = "luamqtt"
version = "1.0-1"
source = {
	url = "git://github.com/xHasKx/luamqtt",
	tag = "v1.0",
}
description = {
	summary = "luamqtt - Pure-lua MQTT client",
	detailed = [[
		luamqtt - it's a pure-lua implementation of MQTT client.
	]],
	homepage = "https://github.com/xHasKx/luamqtt",
	license = "MIT"
}
dependencies = {
	"lua >= 5.1, < 5.4",
	"luasocket >= 3.0rc1-2",
}
build = {
	type = "builtin",
	modules = {
		mqtt = "mqtt/init.lua",
		["mqtt.bit53"] = "mqtt/bit53.lua",
		["mqtt.bit"] = "mqtt/bit.lua",
		["mqtt.luasocket"] = "mqtt/luasocket.lua",
		["mqtt.protocol"] = "mqtt/protocol.lua",
		["mqtt.tools"] = "mqtt/tools.lua",
	},
}
