#!/bin/bash

set -e

ROOT="./local/openwrt"
TARGET=$ROOT/luamqtt.ipk

# check we have access to the luamqtt sources
if [ ! -f mqtt/init.lua ]; then
	cat << EOF
This is a script to create luamqtt.ipk OpenWRT package file without building it
like any usual OpenWRT package (because this may take a lot of time).

We can do this because luamqtt is written in a pure-Lua code, so we don't need
to compile any platform-depended code to make an OpenWRT package from it.

Any .ipk file is like a *.deb Debian package archive. So we'll just create a
folder, put source files in it at right paths, pack them into tar/gzip several
times and there will be an installable OpenWRT package file.

Usage:
    git clone git@github.com:xHasKx/luamqtt.git
    cd ./luamqtt
    ./openwrt/make-package-without-openwrt-sources.sh

    Then check the file $TARGET

Installation on OpenWRT:
    opkg update && opkg install luabitop luasocket luasec
    # copy $TARGET to your OpenWRT machine, through scp, for example
    opkg install ./luamqtt.ipk

EOF
	exit 1
fi

# prepare package building root folder
PKG_ROOT="$ROOT/package"
rm -rf $PKG_ROOT
mkdir -p $PKG_ROOT

# prepare data.tar.gz
mkdir -p $PKG_ROOT/usr/lib/lua
cp -r ./mqtt $PKG_ROOT/usr/lib/lua/
tar --owner=root --group=root -C $PKG_ROOT --exclude=data.tar.gz -czf $PKG_ROOT/data.tar.gz .
rm -rf $PKG_ROOT/usr

# TODO: calculate 'Installed-Size:' somehow; not important

# prepare control.tar.gz
cat << EOF > $PKG_ROOT/control
Package: luamqtt
Version: 3.4.1-1
Depends: libc, lua, luasocket, luabitop, luasec
Source: https://github.com/xHasKx/luamqtt
SourceName: luamqtt
Section: lang
Maintainer: Alexander Kiranov <xhaskx@gmail.com>
Architecture: all
Installed-Size: 23592
Description:  MQTT ( http://mqtt.org/ ) client library for Lua. MQTT is a popular network communication protocol working by "publish/subscribe" model.
EOF

cat << EOF > $PKG_ROOT/postinst
#!/bin/sh
[ "\${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -x \${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. \${IPKG_INSTROOT}/lib/functions.sh
default_postinst \$0 \$@
EOF
chmod +x $PKG_ROOT/postinst

cat << EOF > $PKG_ROOT/prerm
#!/bin/sh
[ -x \${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. \${IPKG_INSTROOT}/lib/functions.sh
default_prerm \$0 \$@
EOF
chmod +x $PKG_ROOT/prerm

tar --owner=root --group=root -C $PKG_ROOT --exclude=control.tar.gz --exclude=data.tar.gz -czf $PKG_ROOT/control.tar.gz .
rm $PKG_ROOT/control $PKG_ROOT/postinst $PKG_ROOT/prerm

# pack the package file
printf '2.0\n' > $PKG_ROOT/debian-binary
[ -f $TARGET ] && rm $TARGET
tar --owner=root --group=root -C $PKG_ROOT -czf $TARGET ./debian-binary ./data.tar.gz ./control.tar.gz

echo "Package ready in $TARGET"
