include $(TOPDIR)/rules.mk

PKG_NAME:=luamqtt
PKG_VERSION:=1.4
PKG_RELEASE:=1
PKG_MAINTAINER:=Mikhail Zoryn <mizo@gurtam.com>

PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/xHasKx/$(PKG_NAME)/archive/

include $(INCLUDE_DIR)/package.mk

define Package/luamqtt
  SUBMENU:=Lua
  SECTION:=lang
  CATEGORY:=Languages
  TITLE:=lua-mqtt
  URL:=https://github.com/xHasKx/luamqtt
  DEPENDS:=+lua +luasocket +luabitop +luasec
endef

define Package/luamqtt/description
  MQTT ( http://mqtt.org/ ) client library for Lua. MQTT is a popular network communication protocol working by "publish/subscribe" model.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luamqtt/install
  $(INSTALL_DIR) $(1)/usr/lib/lua
  $(INSTALL_DIR) $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/init.lua $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/bit53.lua $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/bitwrap.lua $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/luasocket.lua $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/luasocket_ssl.lua $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/protocol.lua $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/protocol4.lua $(1)/usr/lib/lua/mqtt
  $(INSTALL_DATA) $(PKG_BUILD_DIR)/mqtt/tools.lua $(1)/usr/lib/lua/mqtt
endef

$(eval $(call BuildPackage,luamqtt))
