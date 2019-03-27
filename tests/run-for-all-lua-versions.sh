#!/bin/bash

# run luamqtt tests for all supported lua versions
# hererocks should be installed: https://github.com/mpeterv/hererocks
# like this: sudo pip install hererocks

set -e
ROOT="local/hererocks"
mkdir -p $ROOT

for ver in -l5.1 -l5.2 -l5.3 -j2.0 -j2.1; do
	env="$ROOT/v$ver"

	echo "installing lua $ver"
	hererocks "$env" $ver -rlatest >/dev/null

	echo "installing deps"
	source "$env/bin/activate"
	if [ "$ver" == "-l5.1" ] || [ "$ver" == "-l5.2" ]; then
		luarocks install luabitop > /dev/null 2>&1
	fi
	luarocks install busted > /dev/null 2>&1
	if [ -d /usr/lib/x86_64-linux-gnu ]; then
		# debian-based OS
		luarocks install luasec OPENSSL_LIBDIR=/usr/lib/x86_64-linux-gnu > /dev/null 2>&1
	else
		luarocks install luasec > /dev/null 2>&1
	fi

	echo "running tests for $ver"
	busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/*.lua

	if [ "$ver" == "-l5.1" ]; then
		echo "testing luarocks download for luamqtt"
		luarocks install luamqtt >/dev/null 2>&1
		busted tests/spec/*.lua
	fi
done
