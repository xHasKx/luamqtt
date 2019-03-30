# luamqtt - Pure-lua MQTT client

[![License](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](https://github.com/xHasKx/luamqtt/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/xHasKx/luamqtt.svg?branch=master)](https://travis-ci.org/xHasKx/luamqtt)

MQTT ( [http://mqtt.org/](http://mqtt.org/) ) client library for Lua.
**MQTT** is a popular network communication protocol working by **"publish/subscribe"** model.

This library is written in **pure-lua** to provide maximum portability.

# Features

* Full MQTT v3.1.1 client-side support
* Several long-living MQTT clients in one script thanks to ioloop

# Documentation

See [https://xhaskx.github.io/luamqtt/](https://xhaskx.github.io/luamqtt/)

# Source Code

[https://github.com/xHasKx/luamqtt](https://github.com/xHasKx/luamqtt)

# Dependencies

The only main dependency is a [**luasocket**](https://luarocks.org/modules/luarocks/luasocket) to establishing TCP connection to the MQTT broker.

On Lua 5.1 and Lua 5.2 it also depends on [**LuaBitOp**](http://bitop.luajit.org/) (**bit**) library to perform bitwise operations.
It's not listed in package dependencies, please install it manually like this:

    luarocks install luabitop

## luasec (SSL/TLS)

To establish secure network connection (SSL/TSL) to MQTT broker
you also need [**luasec**](https://github.com/brunoos/luasec) module, please install it manually like this:

    luarocks install luasec

This stage is optional and may be skipped if you don't need the secure network connection (e.g. broker is located in your local network).

# Lua versions

It's tested to work on Debian 9 GNU/Linux with Lua versions:
* Lua 5.1 ... Lua 5.3 (**i.e. any modern Lua version**)
* LuaJIT 2.0.0 ... LuaJIT 2.1.0 beta3
* It may also work on other Lua versions without any guarantees

Also I've successfully run it under **Windows** and it was ok, but installing luarock-modules may be a non-trivial task on this OS.

# Installation

    luarocks install luamqtt

[LuaRocks page](http://luarocks.org/modules/xhaskx/luamqtt)

# Examples

Here is a short version of [`examples/simple.lua`](examples/simple.lua):

```lua
-- load mqtt library
local mqtt = require("mqtt")

-- create MQTT client
local client = mqtt.client{ uri = "test.mosquitto.org", clean = true }

-- assign MQTT client event handlers
client:on{
    connect = function(connack)
        -- called on successfull connect

        -- now subscribe to test topic and publish message after it
        assert(client:subscribe("luamqtt/#", 1, function()
            assert(client:publish{ topic = "luamqtt/simpletest", payload = "hello" })
        end))
    end,

    message = function(msg)
        assert(client:acknowledge(msg))

        -- receive one message and disconnect
        print("received message", msg)
        client:disconnect()
    end,
}

-- run ioloop for client
mqtt.run_ioloop(client)
```

More examples placed in [`examples/`](examples/) directory. Also checkout tests in [`tests/spec/mqtt-client.lua`](tests/spec/mqtt-client.lua)

To run tests in this git repo you need [**busted**](https://luarocks.org/modules/olivine-labs/busted):

    busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/*.lua

There is a script to run all tests for all supported lua versions, using [hererocks](https://github.com/mpeterv/hererocks):

    ./tests/run-for-all-lua-versions.sh

Also you can learn MQTT protocol by reading [`tests/spec/protocol-make.lua`](tests/spec/protocol-make.lua) and [`tests/spec/protocol-parse.lua`](tests/spec/protocol-parse.lua) tests

# Connectors

Connector is a network connection layer for luamqtt. There is a two standard connectors included - [`luasocket`](mqtt/luasocket.lua) and [`luasocket_ssl`](mqtt/luasocket_ssl.lua).

In simple terms, connector is a set of functions to establish a network stream (TCP connection usually) and send/receive data through it.
Every MQTT client instance may have their own connector.

And it's very simple to implement your own connector to make luamqtt works in your environment.
For example, it may be the [`cosocket implementation for OpenResty`](https://github.com/openresty/lua-nginx-module).

For more details - see the [`source code of MQTT client initializer`](https://github.com/xHasKx/luamqtt/blob/master/mqtt/init.lua#L69).

# MQTT version

Currently supported is [MQTT v3.1.1 protocol](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html) version.

The MQTT 5.0 protocol version is planned to implement in the future.

# TODO

* more permissive args for some methods
* more examples
* check some packet sequences are right
* coroutines and other asyncronous approaches based on some event loop
* [DONE] several clients in one process
* MQTT 5.0

# LICENSE

Standard MIT License, see LICENSE file for full text
