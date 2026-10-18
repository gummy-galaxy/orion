local graph = require("@root/graph")
local types = require("@root/types")

type Doc = types.Doc

-- Card commands take items and group commands take groups. Each names the other when it gets the wrong one.
local function requireItem(doc: Doc, id: string)
	assert(not graph.isGroup(graph.get(doc, id)), `"{id}" is a group; use orion group set`)
end

return requireItem
