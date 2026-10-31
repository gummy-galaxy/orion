local json = require("@std/json")

local coreFields = require("@root/canvas/cardTypes/coreFields")
local getFieldValues = require("@root/canvas/cardTypes/getFieldValues")
local getItem = require("@root/canvas/items/getItem")
local isGroup = require("@root/canvas/groups/isGroup")
local parseFieldValue = require("@root/canvas/cardTypes/parseFieldValue")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Sets a field one of the card's types declares, from typed text, or clears it
-- when the text is empty.
local function setFieldValue(doc: Doc, id: string, name: string, text: string): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take fields")
	assert(not coreFields[name], `set {name} with --{name}`)

	for _, entry in getFieldValues(item) do
		if entry.field.name ~= name then
			continue
		end

		local fields = json.asObject(item.data.fields) or json.object({})
		fields[name] = parseFieldValue(entry.field, text)
		item.data.fields = nil

		-- Objects carry a marker key, so look for a field name.
		for key in fields do
			if type(key) == "string" then
				item.data.fields = fields
				break
			end
		end

		return item
	end

	error(`none of "{id}"'s types has a field named {name}; orion type show lists a type's fields`)
end

return setFieldValue
