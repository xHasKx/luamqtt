-- logging

-- returns a LuaLogging compatible logger object if LuaLogging was already loaded
-- otherwise returns a stub

local ll = package.loaded.logging
if ll and type(ll) == "table" and ll.defaultLogger and
	tostring(ll._VERSION):find("LuaLogging") then
	-- default LuaLogging logger is available
	return ll.defaultLogger()
else
	-- just use a stub logger with only no-op functions
	local nop = function() end
	return setmetatable({}, {
		__index = function(self, key) self[key] = nop return nop end
	})
end
