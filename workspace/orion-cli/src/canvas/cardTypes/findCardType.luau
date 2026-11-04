local cardTypes = require("@root/canvas/cardTypes/types")
local getCardTypeRegistry = require("@root/canvas/cardTypes/getCardTypeRegistry")

type CardType = cardTypes.CardType

-- A registered type by name. A card can carry a name nothing registers, such
-- as one from a source this build doesn't have, so callers fall back.
local function findCardType(name: string): CardType?
	return getCardTypeRegistry().byName[name]
end

return findCardType
