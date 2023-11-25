-- module table
local tools = {}

-- load required stuff
local require = require

local string = require("string")
local str_format = string.format
local str_byte = string.byte

local table = require("table")
local tbl_concat = table.concat
local tbl_sort = table.sort

local type = type
local error = error
local pairs = pairs

local math = require("math")
local math_floor = math.floor


-- Returns string encoded as HEX
function tools.hex(str)
	local res = {}
	for i = 1, #str do
		res[i] = str_format("%02X", str_byte(str, i))
	end
	return tbl_concat(res)
end

-- Integer division function
function tools.div(x, y)
	return math_floor(x / y)
end

-- table.sort callback for tools.sortedpairs()
local function sortedpairs_compare(a, b)
	local a_type = type(a)
	local b_type = type(b)
	if (a_type == "string" and b_type == "string") or (a_type == "number" and b_type == "number") then
		return a < b
	elseif a_type == "number" then
		return true
	elseif b_type == "number" then
		return false
	else
		error("sortedpairs failed to make a stable keys comparison of types "..a_type.." and "..b_type)
	end
end

-- Iterate through table keys and values in stable (sorted) order
function tools.sortedpairs(tbl)
	local keys = {}
	for k in pairs(tbl) do
		local k_type = type(k)
		if k_type ~= "string" and k_type ~= "number" then
			error("sortedpairs failed to make a stable iteration order for key of type "..type(k))
		end
		keys[#keys + 1] = k
	end
	tbl_sort(keys, sortedpairs_compare)
	local i = 0
	return function()
		i = i + 1
		local key = keys[i]
		if key then
			return key, tbl[key]
		end
	end
end

-- export module table
return tools

-- vim: ts=4 sts=4 sw=4 noet ft=lua
