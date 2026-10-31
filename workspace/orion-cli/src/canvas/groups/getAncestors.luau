local findItem = require("@root/canvas/items/findItem")
local types = require("@root/types")

type Doc = types.Doc

local function getAncestors(doc: Doc, id: string): { string }
	local ancestors = {}
	local current = findItem(doc, id)

	while current and current.parentId do
		table.insert(ancestors, current.parentId)
		current = findItem(doc, current.parentId)
	end

	return ancestors
end

return getAncestors
