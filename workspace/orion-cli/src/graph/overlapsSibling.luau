local getGap = require("@root/graph/getGap")
local getSize = require("@root/graph/getSize")
local types = require("@root/types")

type Doc = types.Doc
type Position = types.Position

-- Whether a box at `position` comes closer than one row gap to any of a parent's children, leaving out the ids in
-- `skip`.
local function overlapsSibling(
	doc: Doc,
	parentId: string?,
	position: Position,
	width: number,
	height: number,
	skip: { [string]: boolean }?
): boolean
	local margin = getGap(parentId).y

	for _, item in doc.nodes do
		if item.parentId == parentId and not (skip and skip[item.id]) then
			local itemWidth, itemHeight = getSize(item)

			if
				position.x < item.position.x + itemWidth + margin
				and item.position.x < position.x + width + margin
				and position.y < item.position.y + itemHeight + margin
				and item.position.y < position.y + height + margin
			then
				return true
			end
		end
	end

	return false
end

return overlapsSibling
