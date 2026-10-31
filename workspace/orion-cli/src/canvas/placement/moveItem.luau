local findPlacement = require("@root/canvas/placement/findPlacement")
local getAncestors = require("@root/canvas/groups/getAncestors")
local getGroup = require("@root/canvas/groups/getGroup")
local getItem = require("@root/canvas/items/getItem")
local markForRefit = require("@root/canvas/placement/markForRefit")
local pruneEmptied = require("@root/canvas/groups/pruneEmptied")
local types = require("@root/types")

type Doc = types.Doc

-- Moves an item or group into another group, or to the top level when `groupId`
-- is nil.
local function moveItem(doc: Doc, id: string, groupId: string?)
	local item = getItem(doc, id)

	if groupId then
		getGroup(doc, groupId)
		assert(groupId ~= id and not table.find(getAncestors(doc, groupId), id), "a group can't move inside itself")
	end

	if item.parentId == groupId then
		return
	end

	local previousParent = item.parentId

	-- Node order doesn't matter here; the app sorts parents ahead of children
	-- on load. Its links are already known, so it lands beside the cards it
	-- links to in the new group.
	item.parentId = groupId
	item.position = findPlacement(doc, item)

	if groupId then
		markForRefit(getGroup(doc, groupId))
	end

	pruneEmptied(doc, previousParent)
end

return moveItem
