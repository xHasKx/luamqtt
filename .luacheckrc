--[[

	This is configuration file for luacheck tool: https://github.com/mpeterv/luacheck

	Documentation: http://luacheck.readthedocs.io/en/stable/

--]]

max_line_length = 200

not_globals = {
    "string.len",
    "table.getn",
}

include_files = {
	"**/*.lua",
	"*.rockspec",
	".busted",
	".luacheckrc",
}

files["tests/spec/**/*.lua"] = { std = "+busted" }
files["examples/openresty/**/*.lua"] = { std = "+ngx_lua" }
files["mqtt/ngxsocket.lua"] = { std = "+ngx_lua" }

-- vim: ts=4 sts=4 sw=4 noet ft=lua
