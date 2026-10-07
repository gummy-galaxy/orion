local function parseCommaList(value: string): { string }
	local entries = {}

	for part in value:gmatch("[^,]+") do
		local entry = part:gsub("^%s+", ""):gsub("%s+$", "")

		if entry ~= "" then
			table.insert(entries, entry)
		end
	end

	return entries
end

return parseCommaList
