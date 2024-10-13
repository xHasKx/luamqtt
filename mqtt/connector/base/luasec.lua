-- validates the LuaSec options, and applies defaults
return function(conn)
	if conn.secure then
		local params = conn.secure_params
		if not params then
			-- set default LuaSec options
			conn.secure_params = {
				mode = "client",
				protocol = "any",
				verify = "none",
				options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
			}
			return
		end

		local ok, ssl = pcall(require, conn.ssl_module)
		assert(ok, "ssl_module '"..tostring(conn.ssl_module).."' not found, secure connections unavailable")

		assert(type(params) == "table", "expecting .secure_params to be a table, got: "..type(params))

		params.mode = params.mode or "client"
		assert(params.mode == "client", "secure parameter 'mode' must be set to 'client' if given, got: "..tostring(params.mode))

		local ctx, err = ssl.newcontext(params)
		if not ctx then
			error("Couldn't create secure context: "..tostring(err))
		end
	end
end
