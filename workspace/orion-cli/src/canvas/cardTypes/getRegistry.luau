local builtinTypes = require("@root/canvas/cardTypes/builtinTypes")
local cardTypes = require("@root/canvas/cardTypes/types")
local createRegistry = require("@root/canvas/cardTypes/createRegistry")
local sourcePacks = require("@root/canvas/cardTypes/sourcePacks")

type CardType = cardTypes.CardType
type Registry = cardTypes.Registry

local registry: Registry? = nil

-- Every type this build knows: the ones Orion ships, then each source's.
-- Built once, since packs don't change while Orion runs.
local function getRegistry(): Registry
	if registry then
		return registry
	end

	local packs: { { CardType } } = { builtinTypes }
	local kinds: { string } = {}

	for kind in sourcePacks do
		table.insert(kinds, kind)
	end

	table.sort(kinds)

	for _, kind in kinds do
		table.insert(packs, sourcePacks[kind])
	end

	local created = createRegistry(packs)
	registry = created
	return created
end

return getRegistry
