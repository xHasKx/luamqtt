-- usage:
-- execute `ldoc .` in this docs directory

file = {"../mqtt/init.lua", "../mqtt/client.lua", "../mqtt/ioloop.lua"}
project = "luamqtt"
package = "mqtt"
dir = "."

description = "luamqtt - Pure-lua MQTT client"

examples = {
	"../examples/simple.lua"
}

topics = {"../README.md", "../LICENSE"}

format = "markdown"
plain = true