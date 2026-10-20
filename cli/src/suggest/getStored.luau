local json = require("@std/json")
local suggestTypes = require("@root/suggest/types")
local types = require("@root/types")

type Doc = types.Doc
type Group = suggestTypes.Group
type Result = suggestTypes.Result

local function getStored(doc: Doc): Result
	local saved = doc.suggestions
	local groups: { Group } = {}

	for _, raw in (if saved then json.asArray(saved.groups) else nil) or {} do
		local object = json.asObject(raw)
		local members: { string } = {}

		for _, id in (if object then json.asArray(object.members) else nil) or {} do
			if type(id) == "string" then
				table.insert(members, id)
			end
		end

		if object and type(object.id) == "string" and type(object.title) == "string" then
			table.insert(groups, {
				id = object.id,
				title = object.title,
				members = members,
				reason = if type(object.reason) == "string" then object.reason else "",
				source = if type(object.source) == "string" then object.source else "heuristic",
			})
		end
	end

	return { createdAt = if saved and type(saved.createdAt) == "string" then saved.createdAt else nil, groups = groups }
end

return getStored
