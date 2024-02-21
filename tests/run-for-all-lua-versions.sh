#!/bin/bash

# run luamqtt tests for all supported lua versions
# hererocks should be installed: https://github.com/mpeterv/hererocks
# like this: sudo pip install hererocks

set -e
ROOT="local/hererocks"
mkdir -p $ROOT

for ver in -l5.1 -l5.2 -l5.3 -l5.4 -j2.0 -j2.1; do
	env="$ROOT/v$ver"

	deps=0
	if [ ! -f "$env/bin/activate" ]; then
		echo "installing lua $ver"
		hererocks "$env" $ver -rlatest >/dev/null
		deps=1
	fi

	source "$env/bin/activate"

	# busted flags
	BFLAGS=""

	if [ "$deps" == "1" ]; then
		echo "installing deps for $ver"
		if [ "$ver" == "-l5.1" ]; then
			# luarocks install luabitop > /dev/null
			echo "patching luabitop rockspec by hands..."
			pushd . >/dev/null
			cd "$env"
			wget https://luarocks.org/manifests/luarocks/luabitop-1.0.2-3.rockspec
			sed -i 's/git:/git+https:/' luabitop-1.0.2-3.rockspec
			luarocks install ./luabitop-1.0.2-3.rockspec > /dev/null
			popd >/dev/null
		fi
		luarocks install busted > /dev/null
		luarocks install copas > /dev/null
		if [ -d /usr/lib/x86_64-linux-gnu ]; then
			# debian-based OS
			[ -f /etc/lsb-release ] && . /etc/lsb-release
			if [ "$DISTRIB_CODENAME" == "trusty" ]; then
				# workaround for ubuntu trusty
				echo "using non-latest luasec 0.7-1 on trusty"
				luarocks install luasec 0.7-1 > /dev/null
			else
				luarocks install luasec OPENSSL_LIBDIR=/usr/lib/x86_64-linux-gnu > /dev/null
			fi
		else
			luarocks install luasec > /dev/null
		fi
	fi

	if [ "$ver" == "-l5.1" -a "$COVERAGE" == "1" ]; then
		echo "installing coveralls lib for $ver"
		luarocks install luacov-coveralls
		echo "running tests and collecting coverage for $ver"
		busted -e 'package.path="./?/init.lua;./?.lua;"..package.path;require("luacov.runner")(".luacov")' $BFLAGS tests/spec/*.lua
	else
		echo "running tests for $ver"
		busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' $BFLAGS tests/spec/*.lua
	fi

done

if [ "$1" == "download" ]; then
	ver="-l5.1"
	env="$ROOT/v$ver"
	source "$env/bin/activate"
	echo "testing 'luarocks install luamqtt' for $ver"
	luarocks install luamqtt >/dev/null
	if git describe --exact-match --tags 2>/dev/null >/dev/null; then
		echo "we are on tag, execute tests for $ver"
		busted $BFLAGS tests/spec/*.lua
	fi
fi
