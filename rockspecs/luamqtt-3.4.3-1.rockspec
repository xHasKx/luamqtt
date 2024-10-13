package = "luamqtt"
version = "3.4.3-1"
source = {
	url = "git+https://github.com/xHasKx/luamqtt.git",
	tag = "v3.4.3",
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
	"lua >= 5.1, <= 5.4",
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
		["mqtt.protocol"] = "mqtt/protocol.lua",
		["mqtt.protocol4"] = "mqtt/protocol4.lua",
		["mqtt.protocol5"] = "mqtt/protocol5.lua",
		["mqtt.tools"] = "mqtt/tools.lua",
		["mqtt.log"] = "mqtt/log.lua",
		["mqtt.connector.init"] = "mqtt/connector/init.lua",
		["mqtt.connector.base.buffered_base"] = "mqtt/connector/base/buffered_base.lua",
		["mqtt.connector.base.non_buffered_base"] = "mqtt/connector/base/non_buffered_base.lua",
		["mqtt.connector.base.luasec"] = "mqtt/connector/base/luasec.lua",
		["mqtt.connector.luasocket"] = "mqtt/connector/luasocket.lua",
		["mqtt.connector.copas"] = "mqtt/connector/copas.lua",
		["mqtt.connector.nginx"] = "mqtt/connector/nginx.lua",
		["mqtt.loop.init"] = "mqtt/loop/init.lua",
		["mqtt.loop.detect"] = "mqtt/loop/detect.lua",
		["mqtt.loop.ioloop"] = "mqtt/loop/ioloop.lua",
		["mqtt.loop.copas"] = "mqtt/loop/copas.lua",
		["mqtt.loop.nginx"] = "mqtt/loop/nginx.lua",
	},
}
