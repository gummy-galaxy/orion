local copyValue = require("@root/operations/copyValue")
local linkKey = require("@root/operations/linkKey")
local operationTypes = require("@root/operations/types")
local types = require("@root/types")

type Doc = types.Doc
type Snapshot = operationTypes.Snapshot

-- Copies every node and link as it is now, with its index, for `diffDocs` to compare against later.
local function captureDoc(doc: Doc): Snapshot
	local snapshot: Snapshot = { nodes = {}, links = {} }

	for index, item in doc.nodes do
		snapshot.nodes[item.id] = { index = index, item = copyValue(item) }
	end

	for index, link in doc.links do
		snapshot.links[linkKey(link.from, link.to)] = { index = index, link = copyValue(link) }
	end

	return snapshot
end

return captureDoc
