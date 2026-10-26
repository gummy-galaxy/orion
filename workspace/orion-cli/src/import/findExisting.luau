local findSameRef = require("@root/refs/findSameRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Ref = types.Ref

-- The card that already tracks this ref, matched the way ingest matches it.
local function findExisting(doc: Doc, ref: Ref): Item?
	for _, item in doc.nodes do
		if item.type == "task" and findSameRef(item, ref) then
			return item
		end
	end

	return nil
end

return findExisting
