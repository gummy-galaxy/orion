local cardTypes = require("@root/canvas/cardTypes/types")
local findCardType = require("@root/canvas/cardTypes/findCardType")
local getItemCardTypes = require("@root/canvas/cardTypes/getItemCardTypes")
local types = require("@root/types")

type Item = types.Item
type Meaning = cardTypes.Meaning

-- How a card feeds what Orion derives, from its primary type. A card whose
-- type isn't registered here reads as a step, so it still counts as work.
local function getCardTypeMeaning(item: Item): Meaning?
	local itemTypes = getItemCardTypes(item)

	if not itemTypes then
		return nil
	end

	local cardType = findCardType(itemTypes.primary) or findCardType("step")
	return (assert(cardType, "the step type is always registered")).meaning
end

return getCardTypeMeaning
