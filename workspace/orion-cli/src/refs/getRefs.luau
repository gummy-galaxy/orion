local json = require("@std/json")

local types = require("@root/types")

type Item = types.Item
type Ref = types.Ref

local function getRefs(item: Item): { Ref }
	local refs: { Ref } = {}

	for _, value in json.asArray(item.data.refs) or {} do
		local ref = json.asObject(value) or (if type(value) == "table" then value :: json.Object else nil)

		if
			ref
			and type(ref.source) == "string"
			and ref.source ~= ""
			and (ref.kind == "pull" or ref.kind == "issue" or ref.kind == "branch")
			and type(ref.key) == "string"
			and ref.key ~= ""
		then
			local isValid = true

			for _, field in { "id", "type", "url", "status", "updatedAt" } do
				isValid = isValid and (ref[field] == nil or type(ref[field]) == "string")
			end

			isValid = isValid and (ref.isDone == nil or type(ref.isDone) == "boolean")
			isValid = isValid and (ref.details == nil or json.asObject(ref.details) ~= nil)

			if isValid then
				table.insert(refs, ref :: any)
			end
		end
	end

	return refs
end

return getRefs
