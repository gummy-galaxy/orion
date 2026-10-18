local getItem = require("@root/graph/getItem")
local types = require("@root/types")

type Doc = types.Doc
type Placement = types.Placement

-- Every place a node appears: its own record first, under the node's id, then each extra placement.
local function getPlacements(doc: Doc, id: string): { Placement }
	local item = getItem(doc, id)
	local result: { Placement } =
		{ { id = item.id, node = item.id, parentId = item.parentId, position = item.position } }

	for _, placement in doc.placements or {} do
		if placement.node == id then
			table.insert(result, placement)
		end
	end

	return result
end

return getPlacements
