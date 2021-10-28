#!/bin/bash

# run luamqtt tests for all installed lua versions in the /hererocks folder
# like this: docker run -ti luamqtt-run-tests:latest

set -e

# run tests for all hererocks environments
for env in /hererocks/*; do
	echo "===== running tests for $env"
	source "$env/bin/activate"
	busted -e 'package.path="./?/init.lua;./?.lua;"..package.path' tests/spec/*.lua

done

# and test installation using luarocks
source "/hererocks/l51/bin/activate"
echo "===== testing 'luarocks install luamqtt' for /hererocks/l51..."
luarocks install luamqtt
echo "===== and running tests for just-installed luamqtt in /hererocks/l51..."
busted tests/spec/*.lua
