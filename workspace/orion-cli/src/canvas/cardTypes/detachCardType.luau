local json = require("@std/json")

local getItem = require("@root/canvas/items/getItem")
local getItemCardTypes = require("@root/canvas/cardTypes/getItemCardTypes")
local getStringField = require("@root/common/getStringField")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Takes off a type a person attached. The card's own type and the ones its
-- sources attach come from elsewhere, so they stay.
local function detachCardType(doc: Doc, id: string, name: string): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take types")

	local kept: json.Array = {}
	local found = false

	for _, value in json.asArray(item.data.types) or {} do
		if getStringField(value) == name then
			found = true
		elseif getStringField(value) then
			table.insert(kept, value)
		end
	end

	if not found then
		local itemTypes = assert(getItemCardTypes(item))
		local reason = if item.data.type == name
			then "it's the card's own type"
			elseif table.find(itemTypes.types, name) then "a source attached it"
			else "it doesn't carry it"

		error(`can't detach {name} from "{id}": {reason}`)
	end

	item.data.types = if #kept > 0 then kept else nil
	return item
end

return detachCardType
