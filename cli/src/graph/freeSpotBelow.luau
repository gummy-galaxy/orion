local getGap = require("@root/graph/getGap")
local overlapsSibling = require("@root/graph/overlapsSibling")
local types = require("@root/types")

type Doc = types.Doc
type Position = types.Position

-- The first spot at or below a preferred one that no sibling covers, for a box of the given size, stepping down one row
-- at a time. Ids in `skip` don't count as siblings.
local function freeSpotBelow(
	doc: Doc,
	parentId: string?,
	preferred: Position,
	width: number,
	height: number,
	skip: { [string]: boolean }?
): Position
	local position = { x = preferred.x, y = preferred.y }

	while overlapsSibling(doc, parentId, position, width, height, skip) do
		position.y += height + getGap(parentId).y
	end

	return position
end

return freeSpotBelow
