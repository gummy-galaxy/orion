local json = require("@std/json")

local createId = require("@root/graph/createId")
local geometry = require("@root/geometry")
local getGroup = require("@root/graph/getGroup")
local getNextSlot = require("@root/graph/getNextSlot")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Makes an empty group, inside `parentId` when given. Its size is one card's worth, so layout checks leave room for it.
local function createGroup(doc: Doc, label: string, parentId: string?): Item
	assert(label ~= "", "a group needs a name")

	if parentId then
		getGroup(doc, parentId)
	end

	local group: Item = {
		id = createId(),
		type = "cluster",
		position = getNextSlot(doc, parentId),
		parentId = parentId,
		width = geometry.TASK_WIDTH + geometry.GROUP_PADDING * 2,
		height = geometry.TASK_HEIGHT + geometry.GROUP_HEADER_HEIGHT + geometry.GROUP_PADDING,
		data = json.object({ kind = "cluster", label = label }),
	}
	table.insert(doc.nodes, group)
	return group
end

return createGroup
