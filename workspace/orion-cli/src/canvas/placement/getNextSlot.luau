local geometry = require("@root/geometry")
local getHeaderHeight = require("@root/canvas/groups/getHeaderHeight")
local getItem = require("@root/canvas/items/getItem")
local getSize = require("@root/canvas/placement/getSize")
local types = require("@root/types")

type Doc = types.Doc
type Position = types.Position

-- The next free spot to the right of a parent's children, or of the top level,
-- as far from them as the app's layout spaces pieces with no link between them,
-- so tidying the group later keeps the gap. Ids in `skip` don't count.
local function getNextSlot(doc: Doc, parentId: string?, skip: { [string]: boolean }?): Position
	local right: number? = nil
	local top: number? = nil

	for _, item in doc.nodes do
		if item.parentId == parentId and not (skip and skip[item.id]) then
			local width = getSize(item)
			right = math.max(right or -math.huge, item.position.x + width)
			top = math.min(top or math.huge, item.position.y)
		end
	end

	if right == nil or top == nil then
		return if parentId
			then { x = geometry.GROUP_PADDING, y = getHeaderHeight(getItem(doc, parentId)) }
			else { x = 0, y = 0 }
	end

	local gap = if parentId then geometry.GAP.inner.component else geometry.GAP.top.component
	return { x = (right :: number) + gap, y = top :: number }
end

return getNextSlot
