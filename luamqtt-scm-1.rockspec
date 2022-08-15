local package_name = "luamqtt"
local package_version = "scm"
local rockspec_revision = "1"
local github_account_name = "xHasKx"
local github_repo_name = "luamqtt"

package = package_name
version = package_version.."-"..rockspec_revision
source = {
	url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
	branch = (package_version == "scm") and "master" or nil,
	tag = (package_version ~= "scm") and "v"..package_version or nil,
}
description = {
	summary = "luamqtt - Pure-lua MQTT v3.1.1 and v5.0 client",
	detailed = [[
luamqtt - MQTT v3.1.1 and v5.0 client library written in pure-lua.
The only dependency is luasocket to establish network connection to MQTT broker.
No C-dependencies.
]],
	homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
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
		["mqtt.const"] = "mqtt/const.lua",
		["mqtt.ioloop"] = "mqtt/ioloop.lua",
		["mqtt.bit53"] = "mqtt/bit53.lua",
		["mqtt.bitwrap"] = "mqtt/bitwrap.lua",
		["mqtt.luasocket"] = "mqtt/luasocket.lua",
		["mqtt.luasocket_ssl"] = "mqtt/luasocket_ssl.lua",
		["mqtt.luasocket-copas"] = "mqtt/luasocket-copas.lua",
		["mqtt.ngxsocket"] = "mqtt/ngxsocket.lua",
		["mqtt.protocol"] = "mqtt/protocol.lua",
		["mqtt.protocol4"] = "mqtt/protocol4.lua",
		["mqtt.protocol5"] = "mqtt/protocol5.lua",
		["mqtt.tools"] = "mqtt/tools.lua",
	},
}
