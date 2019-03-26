#!/bin/bash

# run luamqtt tests for all supported lua versions
# hererocks should be installed: https://github.com/mpeterv/hererocks
# like this: sudo pip install hererocks

ROOT="local/hererocks"
mkdir -p $ROOT

for ver in -l5.1 -l5.2 -l5.3 -j2.0 -j2.1; do
	env="$ROOT/v$ver"

	echo "installing lua $ver"
	hererocks "$env" $ver -rlatest >/dev/null

	echo "installing deps"
	source "$env/bin/activate"
	luarocks install luabitop > /dev/null
	luarocks install busted > /dev/null
	luarocks install luasec > /dev/null

	echo "running tests for $ver"
	busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/*.lua

done
