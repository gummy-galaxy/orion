local findItem = require("@root/graph/findItem")
local findPlacement = require("@root/graph/findPlacement")
local getGroup = require("@root/graph/getGroup")
local getItem = require("@root/graph/getItem")
local getPlacements = require("@root/graph/getPlacements")
local markForTidy = require("@root/graph/markForTidy")
local types = require("@root/types")

type Doc = types.Doc
type Placement = types.Placement
type Position = types.Position

local function isTaken(doc: Doc, id: string): boolean
	return findItem(doc, id) ~= nil or findPlacement(doc, id) ~= nil
end

local function getFreeId(doc: Doc, base: string): string
	if not isTaken(doc, base) then
		return base
	end

	local suffix = 2

	while isTaken(doc, `{base}-{suffix}`) do
		suffix += 1
	end

	return `{base}-{suffix}`
end

-- Places a card again, in another group or at the top level, and returns the new placement. The card keeps one
-- record, so every copy reads and edits the same thing, and links still join the card rather than a copy. A card
-- appears at most once in each group. Without a position, the group is marked so the app lays the copy out.
local function addPlacement(
	doc: Doc,
	id: string,
	groupId: string?,
	position: Position?,
	placementId: string?
): Placement
	local item = getItem(doc, id)
	assert(item.type == "task", `"{id}" is a {item.type}; only cards can be placed again so far`)

	if groupId then
		getGroup(doc, groupId)
	end

	for _, existing in getPlacements(doc, id) do
		assert(existing.parentId ~= groupId, `"{id}" is already in {groupId or "the top level"}`)
	end

	local newId = placementId or getFreeId(doc, `{id}-copy`)
	assert(not isTaken(doc, newId), `"{newId}" is already taken`)

	local placement: Placement = { id = newId, node = id, parentId = groupId, position = position or { x = 0, y = 0 } }
	local placements = doc.placements or {}
	table.insert(placements, placement)
	doc.placements = placements

	if groupId and not position then
		markForTidy(doc, groupId)
	end

	return placement
end

return addPlacement
