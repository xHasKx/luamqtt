local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	id = "luamqtt-example-will-1",
	-- NOTE: this broker is not working sometimes; comment auth = {...} below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	auth = {username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"},
	clean = true,
	ssl = true,
	-- specifying last will message
	will = {
		topic = "luamqtt/lost",
		payload = "client-1 connection lost",
	},
}

-- connect to broker, using assert to raise error on failure
assert(client:connect())
print("connected")

-- subscribe to topic when we are expecting connection close command from client-2
assert(client:subscribe{
	topic = "luamqtt/close",
	qos = 1
})
print("subscribed to luamqtt/close, waiting for connection close command from client-2")

-- receive one message from client-2 then break the connection without sending DISCONNECT packet
client:on("message", function(msg)
	print("received message", msg)
	print("closing connection without DISCONNECT and stopping client-1")
	client:close_connection()
end)

-- start receive loop
assert(client:receive_loop())
