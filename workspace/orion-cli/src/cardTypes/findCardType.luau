local cardTypes = require("@root/cardTypes/types")
local getRegistry = require("@root/cardTypes/getRegistry")

type CardType = cardTypes.CardType

-- A registered type by name. A card can carry a name nothing registers, such
-- as one from a source this build doesn't have, so callers fall back.
local function findCardType(name: string): CardType?
	return getRegistry().byName[name]
end

return findCardType
