local findPlacement = require("@root/graph/findPlacement")
local getGroup = require("@root/graph/getGroup")
local getPlacements = require("@root/graph/getPlacements")
local pruneEmptied = require("@root/graph/pruneEmptied")
local types = require("@root/types")

type Doc = types.Doc
type Position = types.Position

-- Moves one copy to a group, or the top level, at a position. A card's own record moves with `move` and `place`.
local function movePlacement(doc: Doc, id: string, groupId: string?, position: Position)
	local placement = assert(findPlacement(doc, id), `no placement with id "{id}"`)
	local from = placement.parentId

	if groupId ~= from then
		if groupId then
			getGroup(doc, groupId)
		end

		for _, other in getPlacements(doc, placement.node) do
			assert(other.parentId ~= groupId, `"{placement.node}" is already in {groupId or "the top level"}`)
		end
	end

	placement.parentId = groupId
	placement.position = { x = position.x, y = position.y }

	if from ~= groupId then
		pruneEmptied(doc, from)
	end
end

return movePlacement
