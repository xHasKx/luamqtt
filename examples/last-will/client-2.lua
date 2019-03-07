local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	id = "luamqtt-example-will-2",
	-- NOTE: this broker is not working sometimes; comment auth = {...} below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	auth = {username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"},
	clean = true,
	ssl = true,
}

-- connect to broker, using assert to raise error on failure
assert(client:connect())
print("connected")

-- subscribe to topic when we are expecting last-will message from client-1
assert(client:subscribe{
	topic = "luamqtt/lost",
	qos = 1
})
print("subscribed to luamqtt/lost")

-- receive message and stop
client:on("message", function(msg)
	print("received last-will message", msg)
	print("disconnecting and stopping client-2")
	client:disconnect()
end)

-- publish close command to client-1
assert(client:publish{
	topic = "luamqtt/close",
	payload = "Dear client-1, please close your connection",
	qos = 1
})
print("published close command")

-- start receive loop
assert(client:receive_loop())
