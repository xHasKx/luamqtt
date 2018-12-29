--[[
See http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html#_Toc384800405

Section 3.1.4 Response, Non normative comment:

	Clients typically wait for a CONNACK Packet, However, if the Client exploits its freedom
	to send Control Packets before it receives a CONNACK, it might simplify the Client implementation
	as it does not have to police the connected state. The Client accepts that any data that it sends
	before it receives a CONNACK packet from the Server will not be processed if the Server rejects the connection.

]]

-- NOTE: use in pair with examples/quick-receive.lua

-- load mqtt library
local mqtt = require("mqtt")

-- create mqtt client
local client = mqtt.client{
	uri = "test.mosquitto.org", -- NOTE: this broker is not working sometimes
	clean = true,
}

-- connect to broker, quick-and-dirty, don't waiting for CONNACK and don't checking any results
client:_open_connection()
client:_send_connect()

-- publish with zero QoS
client:publish{
	topic = "test/quick-and-dirty",
	payload = "sensor value",
	qos = 0,
}

-- and close connection without loosing time to clean DISCONNECT
client:close_connection()
