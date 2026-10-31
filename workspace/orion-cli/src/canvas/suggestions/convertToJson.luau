local json = require("@std/json")
local suggestTypes = require("@root/canvas/suggestions/types")

type Result = suggestTypes.Result

local function convertToJson(result: Result): json.Object
	local groups: json.Array = {}

	for _, group in result.groups do
		local value = json.object({
			id = group.id,
			title = group.title,
			members = group.members,
			source = group.source,
		})
		value.reason = if group.reason ~= "" then group.reason else nil
		table.insert(groups, value)
	end

	return json.object({ createdAt = result.createdAt, groups = groups })
end

return convertToJson
