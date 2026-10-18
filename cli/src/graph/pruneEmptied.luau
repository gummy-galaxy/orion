local findItem = require("@root/graph/findItem")
local isGroup = require("@root/graph/isGroup")
local types = require("@root/types")

type Doc = types.Doc

-- Removes a group that an edit left with nothing inside, then checks the group that holds it the same way. Only groups
-- the edit emptied go, so a group made empty on purpose, such as by group create, stays until something lands in it.
local function pruneEmptied(doc: Doc, groupId: string?)
	local current = groupId

	while current do
		local group = findItem(doc, current)

		if group == nil or not isGroup(group) then
			return
		end

		for _, other in doc.nodes do
			if other.parentId == current then
				return
			end
		end

		for index, node in doc.nodes do
			if node.id == current then
				table.remove(doc.nodes, index)
				break
			end
		end

		current = group.parentId
	end
end

return pruneEmptied
