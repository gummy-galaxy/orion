local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Everything inside a group at any depth, parents before their children.
local function getContents(doc: Doc, id: string): { Item }
	local contents: { Item } = {}
	local parents = { id }
	local index = 1

	while index <= #parents do
		for _, item in doc.nodes do
			if item.parentId == parents[index] then
				table.insert(contents, item)

				if isGroup(item) then
					table.insert(parents, item.id)
				end
			end
		end

		index += 1
	end

	return contents
end

return getContents
