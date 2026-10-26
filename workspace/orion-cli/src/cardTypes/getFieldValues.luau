local json = require("@std/json")

local cardTypes = require("@root/cardTypes/types")
local coreFields = require("@root/cardTypes/coreFields")
local findCardType = require("@root/cardTypes/findCardType")
local getItemTypes = require("@root/cardTypes/getItemTypes")
local types = require("@root/types")

type FieldValue = cardTypes.FieldValue
type Item = types.Item

-- Every field a card's types declare, primary type first and each name once,
-- with the card's value or else the field's default.
local function getFieldValues(item: Item): { FieldValue }
	local itemTypes = getItemTypes(item)
	local stored = json.asObject(item.data.fields) or json.object({})
	local result: { FieldValue } = {}
	local seen: { [string]: boolean } = {}

	for _, name in if itemTypes then itemTypes.types else {} do
		local cardType = findCardType(name)

		for _, field in if cardType then cardType.fields else {} do
			if seen[field.name] then
				continue
			end

			seen[field.name] = true
			local value = if coreFields[field.name] then item.data[field.name] else stored[field.name]

			if value == nil then
				value = field.default
			end

			table.insert(result, { field = field, type = name, value = value })
		end
	end

	return result
end

return getFieldValues
