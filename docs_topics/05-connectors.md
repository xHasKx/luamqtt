# Connectors

A connector is a network connection layer for luamqtt. This ensures clean separation between the socket
implementation and the client/protocol implementation.

By default luamqtt ships with connectors for `ioloop`, `copas`, and `nginx`. It will auto-detect which
one to use using the `mqtt.loop` module.

## building your own

If you have a different socket implementation you can write your own connector.

There are 2 base-classes `mqtt.connector.base.buffered-base` and `mqtt.connector.base.non-buffered-base`
to build on, which to pick depends on the environment.

The main question is what event/io loop mechanism does your implementation have?

* a single main (co)routione that runs, and doesn't yield when doing network IO. In this case
  you should use the `buffered_base` and read on sockets with a `0` timeout. Check the
  `mqtt.connector.luasocket` implementation for an example (this is what `ioloop` uses).

* multiple co-routines that run within a scheduler, and doing non-blocking network IO (receive/send
  will implicitly yield control to the scheduler so it will run other tasks until the socket is ready).
  This is what Copas and Nginx do, and it requires the `non_buffered_base`.

The main thing to look for when checking out the existing implementations is the network timeout settings,
and the returned `signals`.



