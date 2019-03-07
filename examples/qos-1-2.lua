-- load mqtt library
local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	-- NOTE: this broker is not working sometimes; comment auth = {...} below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	auth = {username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"},
	clean = true,
}
print(client)

-- connect to broker, using assert to raise error on failure
assert(client:connect())
print("connected")

-- subscribe to test topic
assert(client:subscribe{
	topic = "luamqtt/test",
	qos = 2
})
print("subscribed")

-- publish with QoS 1
assert(client:publish{
	topic = "luamqtt/test",
	payload = "hello qos 1",
	qos = 1
})
print("published with QoS 1")

-- receive one message and disconnect
client:on("message", function(msg)
	print("received message", msg)
	client:acknowledge(msg)

	if msg.qos == 1 then
		-- publish with QoS 2
		assert(client:publish{
			topic = "luamqtt/test",
			payload = "hello qos 2",
			qos = 2
		})
		print("published with QoS 2")
	elseif msg.qos == 2 then
		print("received with QoS 2, disconnecting")
		client:disconnect()
	end
end)

-- start receive loop
while client.connection do -- or just assert(client:receive_loop())
	assert(client:receive_iteration())
end

print("done")
