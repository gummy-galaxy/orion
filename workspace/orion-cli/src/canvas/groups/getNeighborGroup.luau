local getGroup = require("@root/canvas/groups/getGroup")
local getItem = require("@root/canvas/items/getItem")
local types = require("@root/types")

type Doc = types.Doc

-- The group a new item goes into: the one asked for, or else the group of the
-- item it follows or leads into.
local function getNeighborGroup(doc: Doc, group: string?, after: string?, before: string?): string?
	if group then
		getGroup(doc, group)
		return group
	end

	local neighbor = after or before
	return if neighbor then getItem(doc, neighbor).parentId else nil
end

return getNeighborGroup
