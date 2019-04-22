local log = ngx.log
local timer_at = ngx.timer.at
local ERR = ngx.ERR
local tbl_concat = table.concat

local function trace(...)
	local line = {}
	for i = 1, select("#", ...) do
		line[i] = tostring(select(i, ...))
	end
	log(ERR, tbl_concat(line, " "))
end

trace("main.lua started")

local start_timer

local function on_timer(...)
	trace("on_timer: ", ...)

	local mqtt = require("mqtt")
	local ioloop = require("mqtt.ioloop")

	-- create mqtt client
	local client = mqtt.client{
		-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
		-- uri = "test.mosquitto.org",
		uri = "mqtt.flespi.io",
		-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
		username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
		clean = true,
		connector = require("mqtt.ngxsocket"),
		secure = true, -- optional
	}
	trace("created MQTT client", client)

	client:on{
		connect = function(connack)
			if connack.rc ~= 0 then
				trace("connection to broker failed:", connack)
				return
			end
			trace("connected:", connack) -- successful connection

			-- subscribe to test topic and publish message after it
			assert(client:subscribe{ topic="luamqtt/#", qos=1, callback=function(suback)
				trace("subscribed:", suback)

				-- publish test message
				trace('publishing test message "hello" to "luamqtt/simpletest" topic...')
				assert(client:publish{
					topic = "luamqtt/simpletest",
					payload = "hello",
					qos = 1
				})
			end})
		end,

		message = function(msg)
			assert(client:acknowledge(msg))

			trace("received:", msg)
		end,

		error = function(err)
			trace("MQTT client error:", err)
		end,

		close = function(conn)
			trace("MQTT conn closed:", conn.close_reason)
		end
	}

	trace("begin ioloop")
	local loop = ioloop.create{
		timeout = client.args.keep_alive,
		sleep_function = ngx.sleep,
	}
	loop:add(client)
	client:start_connecting()
	loop:run_until_clients()
	trace("done ioloop")

	-- to reconnect
	start_timer()
end

start_timer = function()
	local ok, err = timer_at(1, on_timer)
	if not ok then
		trace("failed to start timer:", err)
	end
end

start_timer()
