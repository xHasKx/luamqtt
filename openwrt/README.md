# Building a package for OpenWRT

You may build a package with luamqtt library in a standard way, like described here: https://openwrt.org/docs/guide-developer/helloworld/start

But luamqtt is written in pure-lua, so you actually don't have to compile anything, only files should be packed correctly.

There is a bash script to do so: [./make-package-without-openwrt-sources.sh](./make-package-without-openwrt-sources.sh)
