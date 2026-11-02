local cardTypes = require("@root/canvas/cardTypes/types")
local findCardType = require("@root/canvas/cardTypes/findCardType")
local getItemCardTypes = require("@root/canvas/cardTypes/getItemCardTypes")
local types = require("@root/types")

type Item = types.Item
type StateMeaning = cardTypes.StateMeaning

-- The first state a card's primary type declares with a meaning, such as the
-- one that finishing a card records. A type with none falls back to the
-- meaning's own name, which the shipped types use for their states.
local function findState(item: Item, means: StateMeaning): string
	local itemTypes = getItemCardTypes(item)
	local cardType = if itemTypes then findCardType(itemTypes.primary) else nil

	for _, state in if cardType then cardType.states else {} do
		if state.means == means then
			return state.name
		end
	end

	return means
end

return findState
