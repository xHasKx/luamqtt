#!/bin/bash

# run luamqtt tests for all supported lua versions
# hererocks should be installed: https://github.com/mpeterv/hererocks
# like this: sudo pip install hererocks

set -e
ROOT="local/hererocks"
mkdir -p $ROOT

for ver in -l5.1 -l5.2 -l5.3 -j2.0 -j2.1; do
	env="$ROOT/v$ver"

	deps=0
	if [ ! -f "$env/bin/activate" ]; then
		echo "installing lua $ver"
		hererocks "$env" $ver -rlatest >/dev/null
		deps=1
	fi

	source "$env/bin/activate"

	if [ "$deps" == "1" ]; then
		echo "installing deps for $ver"
		if [ "$ver" == "-l5.1" ]; then
			luarocks install luabitop > /dev/null 2>&1
		fi
		luarocks install busted > /dev/null 2>&1
		luarocks install copas > /dev/null 2>&1
		if [ -d /usr/lib/x86_64-linux-gnu ]; then
			# debian-based OS
			[ -f /etc/lsb-release ] && . /etc/lsb-release
			if [ "$DISTRIB_CODENAME" == "trusty" ]; then
				# workaround for ubuntu trusty
				echo "using non-latest luasec 0.7-1 on trusty"
				luarocks install luasec 0.7-1 > /dev/null 2>&1
			else
				luarocks install luasec OPENSSL_LIBDIR=/usr/lib/x86_64-linux-gnu > /dev/null 2>&1
			fi
		else
			luarocks install luasec > /dev/null 2>&1
		fi
	fi

	echo "running tests for $ver"
	busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/*.lua

done

if [ "$1" == "download" ]; then
	ver="-l5.1"
	env="$ROOT/v$ver"
	source "$env/bin/activate"
	echo "testing 'luarocks install luamqtt' for $ver"
	luarocks install luamqtt >/dev/null 2>&1
	busted tests/spec/*.lua

fi
