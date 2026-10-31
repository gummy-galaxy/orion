local findItem = require("@root/canvas/items/findItem")
local findPlacement = require("@root/canvas/placement/findPlacement")
local types = require("@root/types")

type Doc = types.Doc

-- Places items added together once all their links are known, in the order
-- given. Each one sees only the items placed before it, so a chain added in one
-- plan lands in a row. An id that's gone, such as one a later step removed, is
-- skipped.
local function placeTogether(doc: Doc, ids: { string })
	local unplaced: { [string]: boolean } = {}

	for _, id in ids do
		unplaced[id] = true
	end

	for _, id in ids do
		unplaced[id] = nil
		local item = findItem(doc, id)

		if item then
			item.position = findPlacement(doc, item, unplaced)
		end
	end
end

return placeTogether
