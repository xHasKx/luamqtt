#!/bin/bash

set -e

luacheck examples/ mqtt/ tests/ tools/ $*

# NOTE: luacheck treats .rockspec arguments as manifests and checks files from their build.modules,
# so feed rockspecs via stdin to lint the rockspec code itself
for f in ./*.rockspec rockspecs/*.rockspec; do
	luacheck --std rockspec --filename "$f" $* - < "$f"
done
