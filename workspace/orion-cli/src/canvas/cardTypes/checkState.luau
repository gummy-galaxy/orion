local fieldValues = require("@root/fieldValues")
local findCardType = require("@root/canvas/cardTypes/findCardType")
local getItemCardTypes = require("@root/canvas/cardTypes/getItemCardTypes")
local types = require("@root/types")

type Item = types.Item

-- Refuses a state the card's primary type doesn't declare. A type with no
-- states, like a note, takes the shipped ones.
local function checkState(item: Item, name: string)
	local itemTypes = getItemCardTypes(item)
	local cardType = if itemTypes then findCardType(itemTypes.primary) else nil
	local names: { string } = {}

	for _, state in if cardType then cardType.states else {} do
		table.insert(names, state.name)
	end

	if #names == 0 then
		names = table.clone(fieldValues.statuses) :: { string }
	end

	assert(table.find(names, name), `status must be one of {table.concat(names, ", ")}`)
end

return checkState
