package = "luamqtt"
version = "3.4.1-1"
source = {
	url = "git://github.com/xHasKx/luamqtt",
	tag = "v3.4.1",
}
description = {
	summary = "luamqtt - Pure-lua MQTT v3.1.1 and v5.0 client",
	detailed = [[
luamqtt - MQTT v3.1.1 and v5.0 client library written in pure-lua.
The only dependency is luasocket to establish network connection to MQTT broker.
No C-dependencies.
]],
	homepage = "https://github.com/xHasKx/luamqtt",
	license = "MIT",
}
dependencies = {
	"lua >= 5.1, < 5.4",
	"luasocket >= 3.0rc1-2",
}
build = {
	type = "builtin",
	modules = {
		mqtt = "mqtt/init.lua",
		["mqtt.client"] = "mqtt/client.lua",
		["mqtt.ioloop"] = "mqtt/ioloop.lua",
		["mqtt.bit53"] = "mqtt/bit53.lua",
		["mqtt.bitwrap"] = "mqtt/bitwrap.lua",
		["mqtt.luasocket"] = "mqtt/luasocket.lua",
		["mqtt.luasocket_ssl"] = "mqtt/luasocket_ssl.lua",
		["mqtt.ngxsocket"] = "mqtt/ngxsocket.lua",
		["mqtt.protocol"] = "mqtt/protocol.lua",
		["mqtt.protocol4"] = "mqtt/protocol4.lua",
		["mqtt.protocol5"] = "mqtt/protocol5.lua",
		["mqtt.tools"] = "mqtt/tools.lua",
	},
}
