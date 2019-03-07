# Last Will & Testament example

This directory containing two files: `client-1.lua` and `client-2.lua`.

Both are connecting to the same broker.

First file is specifying a last-will message when connected to broker, then it waits for connection close command.

Second file is sending a close command to the first one, then it waits for the last-will message from client-1, delivered by broker.

When first is receiving close command - it's closing network connection to broker without sending DISCONNECT packet.
This is a simulation of connection lost event.

To reproduce you have to start `client-1.lua` and then `client-2.lua`.

Here is an example output of both scripts:

```
$ lua examples/last-will/client-1.lua
connected
subscribed to luamqtt/close, waiting for connection close command from client-2
received message        PUBLISH{type=3, payload=Dear client-1, please close your connection, topic=luamqtt/close, packet_id=1, retain=false, dup=false, qos=1}
closing connection without DISCONNECT and stopping client-1
```

```
$ lua examples/last-will/client-2.lua
connected
subscribed to luamqtt/lost
published close command
received last-will message      PUBLISH{payload=client-1 connection lost, type=3, packet_id=1, dup=false, topic=luamqtt/lost, retain=false, qos=1}
disconnecting and stopping client-2
```
