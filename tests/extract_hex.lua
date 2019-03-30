local tbl_concat = table.concat

-- Extract only HEX symbols from each line of str, ignoring comments after "--"
local function extract_hex(str)
	local res = {}
	-- iterate through lines
	for line in str:gmatch("[^\n]+") do
		-- find a comment start
		local comment_begin = line:find("--", 1, true)
		if comment_begin then
			line = line:sub(1, comment_begin - 1)
		end
		-- remove all non-hex symbols
		line = line:gsub("[^0-9A-F]+", "")
		-- and append line to concat list
		res[#res + 1] = line
	end
	return tbl_concat(res)
end

return extract_hex
