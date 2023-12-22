--- Nginx specific client handling module.
-- Typically this module is not used directly, but through `mqtt.loop` when
-- auto-detecting the environment.
-- @module mqtt.loop.nginx

local client_registry = {}

local _M = {}


--- Add MQTT client to the Nginx environment.
-- The client will automatically be removed after it exits. It will set up a
-- thread to call `Client:check_keep_alive`.
-- @param client mqtt-client to add to the Nginx environment
-- @return `true` on success or `false` and error message on failure
function _M.add(client)
	if client_registry[client] then
		ngx.log(ngx.WARN, "MQTT client '%s' was already added to Nginx", client.opts.id)
		return false, "MQTT client was already added to Nginx"
	end

	do -- make mqtt device async for incoming packets
		local handle_received_packet = client.handle_received_packet

		-- replace packet handler; create a new thread for each packet received
		client.handle_received_packet = function(mqttdevice, packet)
			ngx.thread.spawn(handle_received_packet, mqttdevice, packet)
			return true
		end
	end


	local ok, err = ngx.timer.at(0, function()
		-- spawn a thread to listen on the socket
		local coro = ngx.thread.spawn(function()
			while true do
				local sleeptime = client:step()
				if not sleeptime then
					ngx.log(ngx.INFO, "MQTT client '", client.opts.id, "' exited, stopping client-thread")
					client_registry[client] = nil
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
		client_registry[client] = nil
		ngx.log(ngx.DEBUG, "MQTT client '", client.opts.id, "' keep-alive loop exited")
		client:disconnect()
		ngx.thread.wait(coro)
		ngx.log(ngx.DEBUG, "MQTT client '", client.opts.id, "' exit complete")
	end)

	if not ok then
		ngx.log(ngx.CRIT, "Failed to start timer-context for device '", client.id,"': ", err)
		return false, "timer failed: " .. err
	end

	return true
end


return setmetatable(_M, {
	__call = function(self, ...)
		return self.add(...)
	end,
})
