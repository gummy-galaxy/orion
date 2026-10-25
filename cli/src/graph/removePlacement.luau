local findPlacementById = require("@root/graph/findPlacementById")
local getItem = require("@root/graph/getItem")
local getPlacements = require("@root/graph/getPlacements")
local pruneEmptied = require("@root/graph/pruneEmptied")
local types = require("@root/types")

type Doc = types.Doc

local function dropPlacement(doc: Doc, id: string)
	local _, index = findPlacementById(doc, id)
	local placements = doc.placements

	if index and placements then
		table.remove(placements, index)
		doc.placements = if #placements > 0 then placements else nil
	end
end

-- Takes one appearance of a node off the canvas and keeps the node, with its links and its other placements.
-- Removing the node's own record moves its first copy into that record's place. The last placement can't go this
-- way, since the node would have nowhere to be; remove the node instead.
local function removePlacement(doc: Doc, id: string)
	local placement = findPlacementById(doc, id)
	local parentId: string?

	if placement then
		parentId = placement.parentId
		dropPlacement(doc, id)
	else
		local item = getItem(doc, id)
		local placements = getPlacements(doc, id)
		assert(#placements > 1, `"{id}" appears only once; use node remove to delete it`)

		local first = placements[2]
		parentId = item.parentId
		item.parentId = first.parentId
		item.position = first.position
		dropPlacement(doc, first.id)
	end

	pruneEmptied(doc, parentId)
end

return removePlacement
