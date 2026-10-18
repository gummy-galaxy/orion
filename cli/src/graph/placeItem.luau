local getItem = require("@root/graph/getItem")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Position = types.Position

-- Sets where an item sits. A child's position is relative to its group, as the app stores it.
local function placeItem(doc: Doc, id: string, position: Position): Item
	local item = getItem(doc, id)
	item.position = position
	return item
end

return placeItem
