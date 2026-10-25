local findItem = require("@root/graph/findItem")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function getItem(doc: Doc, id: string): Item
	return assert(findItem(doc, id), `no item or group with id "{id}"`)
end

return getItem
