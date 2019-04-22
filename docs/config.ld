-- usage:
-- execute `ldoc .` in this docs directory

file = {"../mqtt/init.lua", "../mqtt/client.lua", "../mqtt/ioloop.lua"}
project = "luamqtt"
package = "mqtt"
dir = "."

description = "luamqtt - Pure-lua MQTT v3.1.1 and v5.0 client"

full_description = "Source code: https://github.com/xHasKx/luamqtt"

examples = {
	"../examples/simple.lua",
	"../examples/sync.lua",
	"../examples/mqtt5-simple.lua",
}

topics = {"../README.md", "../LICENSE"}

format = "markdown"
plain = true
