# Installation

As luamqtt is almost zero-dependency you have to install any optional Lua libraries by
yourself, before using the luamqtt library.

When installing using [LuaRocks](http://luarocks.org/modules/xhaskx/luamqtt), the
LuaSocket dependency will automatically be installed as well, as it is a listed dependency
in the rockspec.

    luarocks install luamqtt

To install from source clone the repo and make sure the `./mqtt/` folder is in your
Lua search path.

Check the [dependencies](./02-dependencies.md) on how (and when) to install those.
