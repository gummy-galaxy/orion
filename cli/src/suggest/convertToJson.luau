local json = require("@std/json")
local suggestTypes = require("@root/suggest/types")

type Result = suggestTypes.Result

local function convertToJson(result: Result): json.Object
	local groups: json.Array = {}

	for _, group in result.groups do
		table.insert(
			groups,
			json.object({
				id = group.id,
				title = group.title,
				members = group.members,
				reason = group.reason,
				source = group.source,
			})
		)
	end

	return json.object({ createdAt = result.createdAt, groups = groups })
end

return convertToJson
