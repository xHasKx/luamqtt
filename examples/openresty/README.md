# openresty example

Provided example is based on [the official Getting Started article](https://openresty.org/en/getting-started.html).

There is a two ways to run MQTT client in openresty:

* in synchronous mode
* in ioloop mode

# synchronous mode

Started MQTT client is connecting, subscribing and waiting for incoming MQTT publications as you code it, without any magic asynchronous work.

**Caveats**: The keep_alive feature will not work as there is no way for MQTT client to break its receive() operation in keep_alive interval and send PINGREQ packet to MQTT broker to maintain connection. It may lead to disconnects from MQTT broker side in absense traffic in opened MQTT connection. After disconnecting from broker there is a way to reconnect using openresty's timer.

# ioloop mode

Started MQTT client is connecting, subscribing and waiting for incoming MQTT publications as you code it, maintaining established connection using PINGREQ packets to broker in configured keep_alive interval.

**Caveats**: own luamqtt's ioloop is based on the ability of sockets to timeout its receive() operation, allowing MQTT client to awake in some configured interval and send PINGREQ packet to broker to maintain opened connection, but on every timeout the openresty is writing such in its error.log:

    stream lua tcp socket read timed out, context: ngx.timer

# Files

* [conf/nginx.conf](conf/nginx.conf): configuration for the nginx daemon to run lua script
* [app/main-sync.lua](app/main-sync.lua): example lua script maintaining connection to some MQTT broker, in synchronous mode
* [app/main-ioloop.lua](app/main-ioloop.lua): example lua script maintaining connection to some MQTT broker, in ioloop mode
* start.sh, stop.sh, restart.sh: optional scripts to manage openresty instance
