local json = require("@std/json")

local cardTypes = require("@root/cardTypes/types")
local getRefType = require("@root/cardTypes/getRefType")
local getRefs = require("@root/refs/getRefs")
local getStringField = require("@root/getStringField")
local isGroup = require("@root/graph/isGroup")
local types = require("@root/types")

type Item = types.Item
type ItemTypes = cardTypes.ItemTypes

-- The types attached to a card: its own kind first, which picks its face, then
-- what its sources attach, in the order of its refs, then what people
-- attached. Each appears once. Groups aren't cards and carry none.
local function getItemTypes(item: Item): ItemTypes?
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
		attach(getRefType(ref))
	end

	for _, value in json.asArray(item.data.types) or {} do
		attach(getStringField(value))
	end

	return { primary = primary, types = attached }
end

return getItemTypes
