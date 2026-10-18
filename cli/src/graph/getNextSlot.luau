local getHeaderHeight = require("@root/graph/getHeaderHeight")
local getItem = require("@root/graph/getItem")
local getSize = require("@root/graph/getSize")
local sizes = require("@root/graph/sizes")
local types = require("@root/types")

type Doc = types.Doc
type Position = types.Position

-- The next free spot to the right of a parent's children, or of the top level.
local function getNextSlot(doc: Doc, parentId: string?): Position
	local right: number? = nil
	local top: number? = nil

	for _, item in doc.nodes do
		if item.parentId == parentId then
			local width = getSize(item)
			right = math.max(right or -math.huge, item.position.x + width)
			top = math.min(top or math.huge, item.position.y)
		end
	end

	if right == nil or top == nil then
		return if parentId
			then { x = sizes.GROUP_PADDING, y = getHeaderHeight(getItem(doc, parentId)) }
			else { x = 0, y = 0 }
	end

	return { x = (right :: number) + (if parentId then sizes.ITEM_GAP else sizes.ITEM_GAP * 2), y = top :: number }
end

return getNextSlot
