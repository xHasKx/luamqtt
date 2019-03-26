# luamqtt examples

The simplest example are in `examples/simple.lua` file.

It's performing all basic MQTT actions:
1. connecting to broker
2. subscribing to topic
3. publishing message after subscription creation
4. receiving self-published message
5. disconnecting from MQTT broker

Here is an expected output of such script:
```
created MQTT client     mqtt.client{id="luamqtt-v2-0-0-5807dc7"}
running ioloop for it
connected:      CONNACK{rc=0, sp=false, type=2}
subscribed:     SUBACK{rc={1}, packet_id=1, type=9}
publishing test message "hello" to "luamqtt/simpletest" topic...
received:       PUBLISH{payload="hello", topic="luamqtt/simpletest", dup=false, retain=false, qos=1, packet_id=1, type=3}
disconnecting...
done, ioloop is stopped
```

## More examples

For other examples please see `examples/last-will/` folder.

Also there is a MQTT client tests in `tests/spec/mqtt-client.lua` file, which also may be a good example.
