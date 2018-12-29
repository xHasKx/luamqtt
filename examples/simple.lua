-- load mqtt library
local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	-- uri = "test.mosquitto.org", -- NOTE: this broker is not working sometimes
	uri = "mqtt.flespi.io",
	auth = {username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"},
	clean = true,
}
print(client)

-- connect to broker, using assert to raise error on failure
assert(client:connect())
print("connected")

-- subscribe to test topic
assert(client:subscribe{
	topic = "luamqtt/#",
	qos = 1
})
print("subscribed")

-- publish
assert(client:publish{
	topic = "luamqtt/simpletest",
	payload = "hello",
	qos = 1
})
print("published")

-- receive one message and disconnect
client:on("message", function(msg)
	print("received message", msg)
	client:disconnect()
end)

-- start receive loop
while client.connection do -- or just assert(client:receive_loop())
	assert(client:receive_iteration())
end

print("done")
