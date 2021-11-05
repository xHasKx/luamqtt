-- example of using luamqtt inside copas ioloop: http://keplerproject.github.io/copas/index.html

local mqtt = require("mqtt")
local copas = require("copas")

local num_pings = 10 -- total number of ping-pongs
local delay = 1 -- delay between ping-pongs
local suffix = tostring(math.random(1000000)) -- mqtt topic suffix to distinct simultaneous running of this script

-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
local token = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9"

local ping = mqtt.client{
	uri = "mqtt.flespi.io",
	username = token,
	clean = true,
	version = mqtt.v50,
	-- NOTE: copas connector
	connector = require("mqtt.luasocket-copas"),
}

local pong = mqtt.client{
	uri = "mqtt.flespi.io",
	username = token,
	clean = true,
	version = mqtt.v50,
	-- NOTE: copas connector
	connector = require("mqtt.luasocket-copas"),
}

ping:on{
	connect = function(connack)
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
				assert(ping:publish{ topic = "luamqtt/copas-ping/"..suffix, payload = "ping"..i, qos = 1 })
			end

			print("ping done")
			assert(ping:publish{ topic = "luamqtt/copas-ping/"..suffix, payload = "done", qos = 1 })
			ping:disconnect()
		end)
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

local function add_client(cl)
	-- add keep-alive timer
	local timer = copas.addthread(function()
		while cl do
			copas.sleep(cl:check_keep_alive())
		end
	end)
	-- add client to connect and listen
	copas.addthread(function()
		while cl do
			local timeout = cl:step()
			if not timeout then
				cl = nil -- exiting, inform keep-alive timer
				copas.wakeup(timer)
			else
				if timeout > 0 then
					copas.sleep(timeout)
				end
			end
		end
	end)
end

print("running copas loop...")

add_client(ping)
add_client(pong)

copas.loop()

print("done, copas loop is stopped")
