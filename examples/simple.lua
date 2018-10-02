-- load mqtt library
local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	uri = "test.mosquitto.org",
	clean = true,
}
print(client)

-- connect to broker, using assert to raise error on failure
assert(client:connect())
print("connected")

-- subscribe to test topic
assert(client:subscribe{
	topic = "test/luamqtt",
	qos = 1
})
print("subscribed")

-- publish
assert(client:publish{
	topic = "test/luamqtt",
	payload = "hello",
	qos = 1
})
print("published")

-- receive one message and disconnect
client:on("message", function(msg)
	print("received message", msg)
	client:disconnect()
end)
assert(client:receive_loop())

print("done")
