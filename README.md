# luamqtt - Pure-lua MQTT v3.1.1 and v5.0 client

![luamqtt logo](./logo.svg)

[![License](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](https://github.com/xHasKx/luamqtt/blob/master/LICENSE)
[![tests](https://github.com/xHasKx/luamqtt/actions/workflows/tests-and-coverage.yml/badge.svg)](https://github.com/xHasKx/luamqtt/actions/workflows/tests-and-coverage.yml)
[![Coverage Status](https://coveralls.io/repos/github/xHasKx/luamqtt/badge.svg?branch=master)](https://coveralls.io/github/xHasKx/luamqtt?branch=master)
[![Mentioned in Awesome MQTT](https://awesome.re/mentioned-badge.svg)](https://github.com/hobbyquaker/awesome-mqtt)
[![forthebadge](https://forthebadge.com/images/badges/powered-by-electricity.svg)](https://forthebadge.com)

MQTT ( [http://mqtt.org/](http://mqtt.org/) ) client library for Lua.
**MQTT** is a popular network communication protocol working by **"publish/subscribe"** model.

This library is written in **pure-lua** to provide maximum portability.

# Features

* Full MQTT v3.1.1 client-side support
* Full MQTT v5.0 client-side support
* Several long-living MQTT clients in one script thanks to ioloop

# Documentation

See [https://xhaskx.github.io/luamqtt/](https://xhaskx.github.io/luamqtt/)

# Forum

See [flespi forum thread](https://forum.flespi.com/d/97-luamqtt-mqtt-client-written-in-pure-lua)

# Source Code

[https://github.com/xHasKx/luamqtt](https://github.com/xHasKx/luamqtt)

# Dependencies

The only main dependency is a [**luasocket**](https://luarocks.org/modules/luasocket/luasocket) to establishing TCP connection to the MQTT broker. Install it like this:

```sh
luarocks install luasocket
```

On Lua 5.1 it also depends on [**LuaBitOp**](http://bitop.luajit.org/) (**bit**) library to perform bitwise operations.
It's not listed in package dependencies, please install it manually like this:

```sh
luarocks install luabitop
```

## luasec (SSL/TLS)

To establish secure network connection (SSL/TSL) to MQTT broker
you also need [**luasec**](https://github.com/brunoos/luasec) module, please install it manually like this:

```sh
luarocks install luasec
```

This stage is optional and may be skipped if you don't need the secure network connection (e.g. broker is located in your local network).

# Lua versions

It's tested to work on Debian 9 GNU/Linux with Lua versions:
* Lua 5.1 ... Lua 5.3 (**i.e. any modern Lua version**)
* LuaJIT 2.0.0 ... LuaJIT 2.1.0 beta3
* It may also work on other Lua versions without any guarantees

Also I've successfully run it under **Windows** and it was ok, but installing luarock-modules may be a non-trivial task on this OS.

# Installation

As the luamqtt is almost zero-dependency you have to install required Lua libraries by yourself, before using the luamqtt library:

```sh
luarocks install luasocket # optional if you will use your own connectors (see below)
luarocks install luabitop  # you don't need this for lua 5.3
luarocks install luasec    # you don't need this if you don't want to use SSL connections
```

Then you may install the luamqtt library itself:

```sh
luarocks install luamqtt
```

[LuaRocks page](http://luarocks.org/modules/xhaskx/luamqtt)

# Examples

Here is a short version of [`examples/simple.lua`](examples/simple.lua):

```lua
-- load mqtt library
local mqtt = require("mqtt")

-- create MQTT client, flespi tokens info: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
local client = mqtt.client{ uri = "mqtt.flespi.io", username = os.getenv("FLESPI_TOKEN"), clean = true }

-- assign MQTT client event handlers
client:on{
    connect = function(connack)
        if connack.rc ~= 0 then
            print("connection to broker failed:", connack:reason_string(), connack)
            return
        end

        -- connection established, now subscribe to test topic and publish a message after
        assert(client:subscribe{ topic="luamqtt/#", qos=1, callback=function()
            assert(client:publish{ topic = "luamqtt/simpletest", payload = "hello" })
        end})
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

Also you can learn MQTT protocol by reading [`tests/spec/protocol4-make.lua`](tests/spec/protocol4-make.lua) and [`tests/spec/protocol4-parse.lua`](tests/spec/protocol4-parse.lua) tests

# Connectors

Connector is a network connection layer for luamqtt. There is a three standard connectors included:

* [`luasocket`](mqtt/luasocket.lua)
* [`luasocket_ssl`](mqtt/luasocket_ssl.lua)
* [`ngxsocket`](mqtt/ngxsocket.lua) - for using in [openresty environment](examples/openresty)

The `luasocket` or `luasocket_ssl` connector will be used by default, if not specified, according `secure=true/false` option per MQTT client.

In simple terms, connector is a set of functions to establish a network stream (TCP connection usually) and send/receive data through it.
Every MQTT client instance may have their own connector.

And it's very simple to implement your own connector to make luamqtt works in your environment.

# Bugs & contributing

Please [file a GitHub issue](https://github.com/xHasKx/luamqtt/issues) if you found any bug.

And of course, any contribution are welcome!

# Tests

To run tests in this git repo you need [**busted**](https://luarocks.org/modules/olivine-labs/busted):

```sh
busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/*.lua
```

There is a script to run all tests for all supported lua versions, using [hererocks](https://github.com/mpeterv/hererocks):

```sh
./tests/run-for-all-lua-versions.sh
```

# Code coverage

Code coverage may be collected using [luacov](https://keplerproject.github.io/luacov/).

To collect code coverage stats - install luacov using luarocks and then execute:

```sh
# collect stats during tests
busted -v -e 'package.path="./?/init.lua;./?.lua;"..package.path;require("luacov.runner")(".luacov")' tests/spec/*.lua

# generate report into luacov.report.out file
luacov
```

# MQTT version

Currently supported is:

* [MQTT v3.1.1 protocol](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html) version.
* [MQTT v5.0 protocol](http://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html) version.

Both protocols has full control packets support.

# LICENSE

Standard MIT License, see LICENSE file for full text

# Version bump checklist

* in file `./mqtt/init.lua`: change `_VERSION` table field
* in file `./openwrt/make-package-without-openwrt-sources.sh`: change `Version: X.Y.Z-P` in $PKG_ROOT/control
* in file `./openwrt/Makefile`: change `PKG_VERSION:=X.Y.Z` and maybe `PKG_RELEASE:=1`
* in file `./luamqtt-X.Y.Z-P.rockspec`: change `version = "X.Y.Z-P"`, `tag = "vX.Y.Z"`, and rename the file itself
* run `./tests/run-for-all-lua-versions.sh` and check output for errors
* run `./openwrt/make-package-without-openwrt-sources.sh` and check output for errors
* run `git commit`, `git tag vX.Y.Z`
* upload renamed `./luamqtt-X.Y.Z-P.rockspec` to https://luarocks.org/upload
* run `git push`, `git push --tags`