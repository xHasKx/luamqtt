-- runs in init_worker_by_lua phase

-- IMPORTANT: set up logging before loading MQTT lib
if pcall(require, "logging.nginx") then
	-- LuaLogging nginx forwarder is available
	ngx.log(ngx.INFO, "forwarding LuaMQTT logs to nginx log, using LuaLogging 'nginx' logger")
	local ll = require("logging")
	ll.defaultLogger(ll.nginx()) -- forward logs to nginx logs
else
	ngx.log(ngx.WARN, "LuaLogging module 'logging.nginx' not found, it is strongly recommended to install that module. ",
		"See https://github.com/lunarmodules/lualogging.")
end


local mqtt = require "mqtt"


local function client_add(client)
	local ok, err = ngx.timer.at(0, function()
		-- spawn a thread to listen on the socket
		local coro = ngx.thread.spawn(function()
			while true do
				local sleeptime = client:step()
				if not sleeptime then
					ngx.log(ngx.INFO, "MQTT client '", client.opts.id, "' exited, stopping client-thread")
					return
				else
					if sleeptime > 0 then
						ngx.sleep(sleeptime * 1000)
					end
				end
			end
		end)

		-- endless keep-alive loop
		while not ngx.worker.exiting() do
			ngx.sleep((client:check_keep_alive())) -- double (()) to trim to 1 argument
		end

		-- exiting
		ngx.log(ngx.DEBUG, "MQTT client '", client.opts.id, "' keep-alive loop exited")
		client:disconnect()
		ngx.thread.wait(coro)
		ngx.log(ngx.DEBUG, "MQTT client '", client.opts.id, "' exit complete")
	end)

	if not ok then
		ngx.log(ngx.CRIT, "Failed to start timer-context for device '", client.id,"': ", err)
	end
end



-- create mqtt client
local client = mqtt.client{
	-- NOTE: this broker is not working sometimes; comment username = "..." below if you still want to use it
	-- uri = "test.mosquitto.org",
	uri = "mqtts://mqtt.flespi.io",
	-- NOTE: more about flespi tokens: https://flespi.com/kb/tokens-access-keys-to-flespi-platform
	username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
	clean = true,

	-- event handlers
	on = {
		connect = function(connack, self)
			if connack.rc ~= 0 then
				return
			end

			-- subscribe to test topic and publish message after it
			assert(self:subscribe{ topic="luamqtt/#", qos=1, callback=function()
				-- publish test message
				assert(self:publish{
					topic = "luamqtt/simpletest",
					payload = "hello",
					qos = 1
				})
			end})
		end,

		message = function(msg, self)
			assert(self:acknowledge(msg))

			ngx.log(ngx.INFO, "received:", msg)
		end,

		close = function(conn)
			ngx.log(ngx.INFO, "MQTT conn closed:", conn.close_reason)
		end
	}
}

-- start the client
client_add(client)
