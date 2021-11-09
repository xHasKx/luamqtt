-- usage:
-- execute `ldoc .` in this docs directory

file = {
	"../mqtt/init.lua",
	"../mqtt/client.lua",
	"../mqtt/ioloop.lua",

	"../mqtt/loop/init.lua",
	"../mqtt/loop/copas.lua",
	"../mqtt/loop/nginx.lua",
	"../mqtt/loop/ioloop.lua",

	"../mqtt/connector/init.lua",
	"../mqtt/connector/copas.lua",
	"../mqtt/connector/nginx.lua",
	"../mqtt/connector/luasocket.lua",
}
project = "luamqtt"
package = "mqtt"
dir = "."

description = "luamqtt - Pure-lua MQTT v3.1.1 and v5.0 client"

full_description = "Source code: https://github.com/xHasKx/luamqtt"

examples = {
	"../examples/simple.lua",
	"../examples/mqtt5-simple.lua",
	"../examples/copas.lua",
	"../examples/openresty/app/openresty.lua",
}

use_markdown_titles = true
topics = {
	"../README.md",
	"../LICENSE",
	"../docs_topics/",
}

format = "markdown"
plain = true
