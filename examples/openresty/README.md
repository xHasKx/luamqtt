# openresty example

Openresty is primarily a server, and accepts incoming connections.
This means that running an MQTT client inside OpenResty will require
some tricks.

Since OpenResty sockets cannot pass a context boundary (without being
closed), and we need a background task listening on the socket, we're
creating a timer context, and then handle everything from within that
context.

In the timer we'll spawn a thread that will do the listening, and the
timer itself will go in an endless loop to do the keepalives.

# Caveats

* Due to the socket limitation we cannot Publish anything from another
  context. If you run into "bad request" errors on socket operations, you
  are probably accessing a socket from another context.
* In the long run, timers do leak memory, since timer contexts are
  supposed to be short-lived. Consider implementing a secondary mechanism
  to restart the timer-context and restart the client.

# Files

* [conf/nginx.conf](conf/nginx.conf): configuration for the nginx daemon to run lua scripts
* [app/openresty.lua](app/openresty.lua): example lua script maintaining connection
* [mqtt/loop/nginx.lua](../../mqtt/loop/nginx.lua): how to add a client in an Nginx environment
* `start.sh`, `stop.sh`, `quit.sh`, `restart.sh`: optional scripts to manage the OpenResty instance
