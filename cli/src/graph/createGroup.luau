local json = require("@std/json")

local getGroup = require("@root/graph/getGroup")
local getNextSlot = require("@root/graph/getNextSlot")
local getUniqueId = require("@root/graph/getUniqueId")
local sizes = require("@root/graph/sizes")
local slugify = require("@root/slugify")
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
		id = getUniqueId(doc, slugify(label)),
		type = "cluster",
		position = getNextSlot(doc, parentId),
		parentId = parentId,
		width = sizes.TASK_WIDTH + sizes.GROUP_PADDING * 2,
		height = sizes.TASK_HEIGHT + sizes.GROUP_HEADER_HEIGHT + sizes.GROUP_PADDING,
		data = json.object({ kind = "cluster", label = label }),
	}
	table.insert(doc.nodes, group)
	return group
end

return createGroup
