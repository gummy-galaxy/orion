local builtinCardTypes = require("@root/canvas/cardTypes/builtinCardTypes")
local cardTypes = require("@root/canvas/cardTypes/types")
local createCardTypeRegistry = require("@root/canvas/cardTypes/createCardTypeRegistry")
local sourceCardTypePacks = require("@root/canvas/cardTypes/sourceCardTypePacks")

type CardType = cardTypes.CardType
type Registry = cardTypes.Registry

local registry: Registry? = nil

-- Every type this build knows: the ones Orion ships, then each source's.
-- Built once, since packs don't change while Orion runs.
local function getCardTypeRegistry(): Registry
	if registry then
		return registry
	end

	local packs: { { CardType } } = { builtinCardTypes }
	local kinds: { string } = {}

	for kind in sourceCardTypePacks do
		table.insert(kinds, kind)
	end

	table.sort(kinds)

	for _, kind in kinds do
		table.insert(packs, sourceCardTypePacks[kind])
	end

	local created = createCardTypeRegistry(packs)
	registry = created
	return created
end

return getCardTypeRegistry
