local graph = require("@root/graph")
local resolveRef = require("@root/adapters/resolveRef")
local types = require("@root/types")

type Doc = types.Doc

-- Attaches the --ref given to add or set, resolving it against the document's sources.
local function attachRequestedRef(doc: Doc, id: string, input: string?)
	if input then
		graph.attachRef(doc, id, resolveRef(input, doc.settings.sources))
	end
end

return attachRequestedRef
