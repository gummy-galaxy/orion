local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function findItem(doc: Doc, id: string): Item?
	for _, item in doc.nodes do
		if item.id == id then
			return item
		end
	end

	return nil
end

return findItem
