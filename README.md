# luamqtt - Pure-lua MQTT client

MQTT ( http://mqtt.org/ ) client library for Lua.
**MQTT** is a popular network communication protocol working by **"publish/subscribe"** model.

This library is written in **pure-lua** to provide maximum portability.

## Features

* Full MQTT v3.1.1 support
* More coming soon

# Dependencies

The only main dependency is a [**luasocket**](https://luarocks.org/modules/luarocks/luasocket) to establishing TCP connection to the MQTT broker.

On Lua 5.1 and Lua 5.2 it also depends on [**LuaBitOp**](http://bitop.luajit.org/) (**bit**) library to perform bitwise operations.
It's not listed in package dependencies, please install it manually like this:

    luarocks install luabitop

# Lua versions

It's tested to work on Debian 9 GNU/Linux with Lua versions:
* Lua 5.1 ... Lua 5.3
* LuaJIT 2.0.0 ... LuaJIT 2.1.0 beta3
* It may also work on other Lua versions without any guarantees

# Installation

    luarocks install luamqtt

# Examples

Checkout tests in [`tests/spec/mqtt-client.lua`](tests/spec/mqtt-client.lua)

To run tests in this git repo you need [**busted**](https://luarocks.org/modules/olivine-labs/busted):

    busted tests/spec/*.lua

Also you can learn MQTT protocol by reading [`tests/spec/protocol-make.lua`](tests/spec/protocol-make.lua) and [`tests/spec/protocol-parse.lua`](tests/spec/protocol-parse.lua) tests

# MQTT version

Currently supported is [MQTT v3.1.1 protocol](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html) version.

The MQTT 5.0 protocol version is planned to implement in the future.

# TODO

* deploy on luarocks
* example in README.md
* will message test
* SSL (by luasec)
* QoS 2
* coroutines and other asyncronous approaches based on some event loop
* several clients in one process
* MQTT 5.0

# LICENSE

Standard MIT License, see LICENSE file for full text
