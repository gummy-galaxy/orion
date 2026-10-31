local json = require("@std/json")

local findCardType = require("@root/canvas/cardTypes/findCardType")
local getItem = require("@root/canvas/items/getItem")
local getItemCardTypes = require("@root/canvas/cardTypes/getItemCardTypes")
local getStringField = require("@root/common/getStringField")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Attaches a registered type to a card on a person's say, after the ones it
-- already carries. A type the card already carries, from anywhere, stays
-- where it is.
local function attachCardType(doc: Doc, id: string, name: string): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take types; attach it to a card")
	assert(findCardType(name), `no type named {name}; orion type list shows them`)

	local itemTypes = assert(getItemCardTypes(item))

	if table.find(itemTypes.types, name) then
		return item
	end

	local attached: json.Array = {}

	for _, value in json.asArray(item.data.types) or {} do
		if getStringField(value) then
			table.insert(attached, value)
		end
	end

	table.insert(attached, name)
	item.data.types = attached
	return item
end

return attachCardType
