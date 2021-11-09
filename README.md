# luamqtt

Pure-lua MQTT v3.1.1 and v5.0 client

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
* Support for Copas, OpenResty/Nginx, and an included lightweight ioloop.

# Documentation

See [https://xhaskx.github.io/luamqtt/](https://xhaskx.github.io/luamqtt/)

# Forum

See [flespi forum thread](https://forum.flespi.com/d/97-luamqtt-mqtt-client-written-in-pure-lua)

# Source Code

[https://github.com/xHasKx/luamqtt](https://github.com/xHasKx/luamqtt)

# Bugs & contributing

Please [file a GitHub issue](https://github.com/xHasKx/luamqtt/issues) if you found any bug.

And of course, any contribution are welcome!

# Tests

To run tests in this git repo you need [**busted**](https://luarocks.org/modules/olivine-labs/busted) as well as some dependencies:

Prepare:
```sh
luarocks install busted
luarocks install luacov
luarocks install luasocket
luarocks install luasec
luarocks install copas
luarocks install lualogging
```

Running the tests:
```sh
busted
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
busted --coverage

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

* in file `./mqtt/const.lua`: change `_VERSION` table field
* in file `./openwrt/make-package-without-openwrt-sources.sh`: change `Version: X.Y.Z-P` in $PKG_ROOT/control
* in file `./openwrt/Makefile`: change `PKG_VERSION:=X.Y.Z` and maybe `PKG_RELEASE:=1`
* copy file `./luamqtt-scm-1.rockspec` to `./rockspecs/luamqtt-X.Y.Z-1.rockspec` change `local package_version = "scm"`, `local package_version = "X.Y.Z"`
* run `./tests/run-luacheck.sh` and check output for errors
* run `./tests/run-markdownlint.sh` and check output for errors
* run `./tests/run-for-all-lua-versions.sh` and check output for errors
* run `./openwrt/make-package-without-openwrt-sources.sh` and check output for errors
* run `git commit`, `git tag vX.Y.Z`
* run `git push`, `git push --tags`
* upload to LuaRocks; `luarocks upload ./rockspecs/luamqtt-X.Y.Z-1.rockspec --api-key=ABCDEFGH`
