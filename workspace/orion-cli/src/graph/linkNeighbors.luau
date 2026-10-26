local insertBetween = require("@root/graph/insertBetween")
local linkItems = require("@root/graph/linkItems")
local types = require("@root/types")

type Doc = types.Doc

-- Links a new item after `after` and before `before`. When both are given and
-- already linked, the item splits that link and keeps its kind; otherwise each
-- side gets a blocking link.
local function linkNeighbors(doc: Doc, id: string, after: string?, before: string?)
	if after and before then
		for _, link in doc.links do
			if link.from == after and link.to == before then
				insertBetween(doc, id, after, before)
				return
			end
		end
	end

	if after then
		linkItems(doc, after, id, "blocks")
	end

	if before then
		linkItems(doc, id, before, "blocks")
	end
end

return linkNeighbors
