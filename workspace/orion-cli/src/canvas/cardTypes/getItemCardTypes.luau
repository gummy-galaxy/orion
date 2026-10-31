local json = require("@std/json")

local cardTypes = require("@root/canvas/cardTypes/types")
local getRefCardType = require("@root/canvas/cardTypes/getRefCardType")
local getRefs = require("@root/canvas/refs/getRefs")
local getStringField = require("@root/common/getStringField")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Item = types.Item
type ItemTypes = cardTypes.ItemTypes

-- The types attached to a card: its own kind first, which picks its face, then
-- what its sources attach, in the order of its refs, then what people
-- attached. Each appears once. Groups aren't cards and carry none.
local function getItemCardTypes(item: Item): ItemTypes?
	if isGroup(item) then
		return nil
	end

	local primary = if item.type == "image" then "image" else getStringField(item.data.itemKind) or "step"
	local attached: { string } = { primary }
	local seen: { [string]: boolean } = { [primary] = true }

	local function attach(name: string?)
		if name and not seen[name] then
			seen[name] = true
			table.insert(attached, name)
		end
	end

	for _, ref in getRefs(item) do
		attach(getRefCardType(ref))
	end

	for _, value in json.asArray(item.data.types) or {} do
		attach(getStringField(value))
	end

	return { primary = primary, types = attached }
end

return getItemCardTypes
