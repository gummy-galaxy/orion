local getGroup = require("@root/canvas/groups/getGroup")
local markForRefit = require("@root/canvas/placement/markForRefit")
local types = require("@root/types")

type Doc = types.Doc

-- Removes a group and hands its items to the group that held it, keeping them
-- where they are on the canvas.
local function ungroup(doc: Doc, id: string)
	local group = getGroup(doc, id)

	for _, item in doc.nodes do
		if item.parentId == id then
			item.parentId = group.parentId
			item.position = { x = item.position.x + group.position.x, y = item.position.y + group.position.y }
		end
	end

	if group.parentId then
		markForRefit(getGroup(doc, group.parentId))
	end

	for index, item in doc.nodes do
		if item.id == id then
			table.remove(doc.nodes, index)
			break
		end
	end
end

return ungroup
