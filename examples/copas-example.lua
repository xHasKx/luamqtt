-- example of using luamqtt inside copas ioloop: http://keplerproject.github.io/copas/index.html

local mqtt = require("mqtt")
local copas = require("copas")
local add_client = require("mqtt.loop").add

local num_pings = 10 -- total number of ping-pongs
local delay = 1 -- delay between ping-pongs
local suffix = tostring(math.random(1000000)) -- mqtt topic suffix to distinct simultaneous running of this script

-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
local token = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"

local ping = mqtt.client{
	uri = "mqtt://mqtt.flespi.io",
	username = token,
	clean = true,
	version = mqtt.v50,

	-- create event handlers
	on = {
		connect = function(connack, self)
			assert(connack.rc == 0)
			print("ping connected")

			-- adding another thread; copas handlers should return quickly, anything
			-- that can wait should be off-loaded from the handler to a thread.
			-- Especially anything that yields; socket reads/writes and sleeps, and the
			-- code below does both, sleeping, and writing (implicit in 'publish')
			copas.addthread(function()
				for i = 1, num_pings do
					copas.sleep(delay)
					print("ping", i)
					assert(self:publish{ topic = "luamqtt/copas-ping/"..suffix, payload = "ping"..i, qos = 1 })
				end

				print("ping done")
				assert(self:publish{ topic = "luamqtt/copas-ping/"..suffix, payload = "done", qos = 1 })
				self:disconnect()
			end)
		end,
		error = function(err)
			print("ping MQTT client error:", err)
		end,
	}, -- close 'on', event handlers
}

local pong = mqtt.client{
	uri = "mqtt://mqtt.flespi.io",
	username = token,
	clean = true,
	version = mqtt.v50,

	-- create event handlers
	on = {
		connect = function(connack, self)
			assert(connack.rc == 0)
			print("pong connected")

			assert(self:subscribe{ topic="luamqtt/copas-ping/"..suffix, qos=1, callback=function(suback)
				assert(suback.rc[1] > 0)
				print("pong subscribed")
			end })
		end,

		message = function(msg, self)
			print("pong: received", msg.payload)
			assert(self:acknowledge(msg))

			if msg.payload == "done" then
				print("pong done")
				self:disconnect()
			end
		end,
		error = function(err)
			print("pong MQTT client error:", err)
		end,
	}, -- close 'on', event handlers
}

print("running copas loop...")

add_client(ping)
add_client(pong)

copas.loop()

print("done, copas loop is stopped")
