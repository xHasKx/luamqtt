-- wrapper around BitOp module

if _VERSION == "Lua 5.1" or type(jit) == "table" then -- Lua 5.1 or LuaJIT (based on Lua 5.1)
	return require("bit") -- custom module https://luarocks.org/modules/luarocks/luabitop
elseif _VERSION == "Lua 5.2" then
	return require("bit32") -- standard Lua 5.2 module
else
	return require("mqtt.bit53")
end

-- vim: ts=4 sts=4 sw=4 noet ft=lua
