local getItem = require("@root/canvas/items/getItem")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function getGroup(doc: Doc, id: string): Item
	local item = getItem(doc, id)
	assert(isGroup(item), `"{id}" is an item, not a group`)
	return item
end

return getGroup
