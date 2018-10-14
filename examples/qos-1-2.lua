-- load mqtt library
local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	uri = "test.mosquitto.org",
	clean = true,
	debug = print,
}
print(client)

-- connect to broker, using assert to raise error on failure
assert(client:connect())
print("connected")

-- subscribe to test topic
assert(client:subscribe{
	topic = "test/luamqtt",
	qos = 2
})
print("subscribed")

-- publish with QoS 1
assert(client:publish{
	topic = "test/luamqtt",
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
			topic = "test/luamqtt",
			payload = "hello qos 2",
			qos = 2
		})
		print("published with QoS 2")
	elseif msg.qos == 2 then
		client:disconnect()
	end
end)
assert(client:receive_loop())

print("done")
