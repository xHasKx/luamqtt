-- example of using luamqtt inside copas ioloop: http://keplerproject.github.io/copas/index.html

local mqtt = require("mqtt")
local copas = require("copas")
local mqtt_ioloop = require("mqtt.ioloop")

local num_pings = 10 -- total number of ping-pongs
local timeout = 1 -- timeout between ping-pongs
local suffix = tostring(math.random(1000000)) -- mqtt topic suffix to distinct simultaneous rinning of this script

-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
local token = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"

local ping = mqtt.client{
	uri = "mqtt.flespi.io",
	username = token,
	clean = true,
	version = mqtt.v50,
}

local pong = mqtt.client{
	uri = "mqtt.flespi.io",
	username = token,
	clean = true,
	version = mqtt.v50,
}

ping:on{
	connect = function(connack)
		assert(connack.rc == 0)
		print("ping connected")

		for i = 1, num_pings do
			copas.sleep(timeout)
			print("ping", i)
			assert(ping:publish{ topic = "luamqtt/copas-ping/"..suffix, payload = "ping"..i, qos = 1 })
		end

		copas.sleep(timeout)

		print("ping done")
		assert(ping:publish{ topic = "luamqtt/copas-ping/"..suffix, payload = "done", qos = 1 })
		ping:disconnect()
	end,
	error = function(err)
		print("ping MQTT client error:", err)
	end,
}

pong:on{
	connect = function(connack)
		assert(connack.rc == 0)
		print("pong connected")

		assert(pong:subscribe{ topic="luamqtt/copas-ping/"..suffix, qos=1, callback=function(suback)
			assert(suback.rc[1] > 0)
			print("pong subscribed")
		end })
	end,

	message = function(msg)
		print("pong: received", msg.payload)
		assert(pong:acknowledge(msg))

		if msg.payload == "done" then
			print("pong done")
			pong:disconnect()
		end
	end,
	error = function(err)
		print("pong MQTT client error:", err)
	end,
}

print("running copas loop...")

copas.addthread(function()
	local ioloop = mqtt_ioloop.create{ sleep = 0.01, sleep_function = copas.sleep }
	ioloop:add(ping)
	ioloop:run_until_clients()
end)

copas.addthread(function()
	local ioloop = mqtt_ioloop.create{ sleep = 0.01, sleep_function = copas.sleep }
	ioloop:add(pong)
	ioloop:run_until_clients()
end)

copas.loop()

print("done, copas loop is stopped")
