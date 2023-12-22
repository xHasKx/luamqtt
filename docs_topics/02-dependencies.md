# Dependencies

The dependencies differ slightly based on the environment you use, and the requirements you have:

* [**luasocket**](https://luarocks.org/modules/luasocket/luasocket) to establish TCP connections to the MQTT broker.
  This is a listed dependency in the luamqtt rockspec, so it will automatically be installed if you use LuaRocks to
  install luamqtt. To install it manually:

      luarocks install luasocket

* [**copas**](https://github.com/keplerproject/copas) module for asynchoneous IO. Copas is an advanced co-routine
  scheduler with far more features than the included `ioloop`. For anything more than a few devices, or for devices which
  require network IO beyond mqtt alone, Copas is the better alternative. Copas is also pure-Lua, but has parallel network
  IO (as opposed to sequential network IO in `ioloop`), and has features like; threads, timers, locks, semaphores, and
  non-blocking clients for http(s), (s)ftp, and smtp.

      luarocks install copas

* [**luasec**](https://github.com/brunoos/luasec) module for SSL/TLS based connections. This is optional and may be
  skipped if you don't need secure network connections (e.g. broker is located in your local network). It's not listed
  in package dependencies, please install it manually like this:

      luarocks install luasec

* [**LuaBitOp**](http://bitop.luajit.org/) library to perform bitwise operations, which is required only on
  Lua 5.1. It's not listed in package dependencies, please install it manually like this:

      luarocks install luabitop

* [**LuaLogging**](https://github.com/lunarmodules/lualogging/) to enable logging by the MQTT client. This is optional
  but highly recommended for long running clients. This is a great debugging aid when developing your clients. Also when
  using OpenResty as your runtime, you'll definitely want to use this, see
  [openresty.lua](https://xhaskx.github.io/luamqtt/examples/openresty.lua.html) for an example.
  It's not listed in package dependencies, please install it manually like this:

      luarocks install lualogging
