--[[

	This is configuration file for luacheck tool: https://github.com/mpeterv/luacheck

	Documentation: http://luacheck.readthedocs.io/en/stable/

--]]

max_line_length = 200

files["mqtt/**"] = {
	ignore = {
		"113/unpack",
	}
}

files["tests/spec/**"] = {
	ignore = {
		"113/describe",
		"113/it",
		"143/assert",
	}
}

-- vim: ts=4 sts=4 sw=4 noet ft=lua
