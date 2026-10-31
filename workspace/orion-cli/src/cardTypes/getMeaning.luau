local cardTypes = require("@root/cardTypes/types")
local findCardType = require("@root/cardTypes/findCardType")
local getItemTypes = require("@root/cardTypes/getItemTypes")
local types = require("@root/types")

type Item = types.Item
type Meaning = cardTypes.Meaning

-- How a card feeds what Orion derives, from its primary type. A card whose
-- type isn't registered here reads as a step, so it still counts as work.
local function getMeaning(item: Item): Meaning?
	local itemTypes = getItemTypes(item)

	if not itemTypes then
		return nil
	end

	local cardType = findCardType(itemTypes.primary) or findCardType("step")
	return (assert(cardType, "the step type is always registered")).meaning
end

return getMeaning
