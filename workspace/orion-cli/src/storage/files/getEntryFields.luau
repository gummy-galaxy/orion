local json = require("@std/json")

--[[
	The fields of a node or link file that merge on their own, keyed by path:
	each top-level field, and each field of `data` as `data.<name>`, so two
	edits to one card's data merge field by field. The id never changes, and
	`changedAt` holds when each of these last did, so neither is a field.
]]
local function getEntryFields(entry: json.Object): { [string]: json.Value }
	local fields: { [string]: json.Value } = {}

	for key, value in entry do
		if type(key) ~= "string" or key == "id" or key == "changedAt" then
			continue
		end

		local data = if key == "data" then json.asObject(value) else nil

		if data then
			for name, field in data do
				if type(name) == "string" then
					fields[`data.{name}`] = field
				end
			end
		else
			fields[key] = value
		end
	end

	return fields
end

return getEntryFields
