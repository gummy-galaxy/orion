local getItem = require("@root/canvas/items/getItem")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Doc = types.Doc

-- Card commands take items and group commands take groups. Each names the other
-- when it gets the wrong one.
local function requireItem(doc: Doc, id: string)
	assert(not isGroup(getItem(doc, id)), `"{id}" is a group; use orion group set`)
end

return requireItem
