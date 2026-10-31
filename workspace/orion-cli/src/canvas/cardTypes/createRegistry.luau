local cardTypes = require("@root/canvas/cardTypes/types")
local checkCardType = require("@root/canvas/cardTypes/checkCardType")

type CardType = cardTypes.CardType
type Registry = cardTypes.Registry

-- Checks every type in the packs and indexes them by name. Packs register
-- through this one path, whether Orion ships them or a source adds them, and
-- a name can be taken only once.
local function createRegistry(packs: { { CardType } }): Registry
	local registry: Registry = { byName = {}, ordered = {} }

	for _, pack in packs do
		for _, cardType in pack do
			checkCardType(cardType)

			local taken = registry.byName[cardType.name]
			assert(not taken, `{cardType.pack} declares {cardType.name}, which {taken and taken.pack} already declares`)

			registry.byName[cardType.name] = cardType
			table.insert(registry.ordered, cardType)
		end
	end

	return registry
end

return createRegistry
