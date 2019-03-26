# Last Will & Testament example

This directory containing two files: `client-1.lua` and `client-2.lua`.

Both are connecting to the **same broker**.

First file is specifying a last-will message when connected to broker, then it waits for connection close command.

Second file is sending a close command to the first one, then it waits for the last-will message from client-1, delivered by broker.

When first is receiving close command - it's closing network connection to broker without sending DISCONNECT packet.
This is a simulation of connection lost event.

To reproduce you have to start `client-1.lua` and then `client-2.lua`.

Here is an example output of both scripts:

```
$ lua examples/last-will/client-1.lua
connected:      CONNACK{rc=0, type=2, sp=false}
subscribed to luamqtt/close, waiting for connection close command from client-2
received:       PUBLISH{qos=1, retain=false, topic="luamqtt/close", payload="Dear client-1, please close your connection", packet_id=1, type=3, dup=false}
closing connection without DISCONNECT and stopping client-1
```

```
$ lua examples/last-will/client-2.lua
connected:      CONNACK{rc=0, sp=false, type=2}
subscribed to luamqtt/lost
published close command
received:       PUBLISH{topic="luamqtt/lost", qos=1, payload="client-1 connection lost last will message", dup=false, packet_id=1, retain=false, type=3}
disconnecting and stopping client-2
```
