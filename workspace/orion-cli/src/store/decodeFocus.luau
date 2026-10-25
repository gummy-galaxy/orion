local json = require("@std/json")

local getStringField = require("@root/getStringField")
local types = require("@root/types")

type Focus = types.Focus

local function decodeFocus(text: string): Focus
	local root = json.asObject(json.deserialize(text) :: json.Value)
	assert(root, "Orion focus must be a JSON object")
	local selected: { string } = {}

	for _, id in json.asArray(root.selected) or {} do
		if type(id) == "string" then
			table.insert(selected, id)
		end
	end

	return { open = getStringField(root.open), selected = selected, updatedAt = getStringField(root.updatedAt) }
end

return decodeFocus
