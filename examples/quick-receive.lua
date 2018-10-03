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

-- subscribe with zero QoS
assert(client:subscribe{
	topic = "test/quick-and-dirty",
	qos = 0,
})
print("subscribed")

-- receive one message and disconnect
client:on("message", function(msg)
	print("received message", msg)
	client:disconnect()
end)
assert(client:receive_loop())

print("done")
