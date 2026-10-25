local getItem = require("@root/graph/getItem")
local getRefs = require("@root/refs/getRefs")
local isGroup = require("@root/graph/isGroup")
local refreshItemKind = require("@root/graph/refreshItemKind")
local removeRef = require("@root/refs/removeRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Takes a ref off an item. A kind narrows the match when the same key could name an issue and a pull request.
local function detachRef(doc: Doc, id: string, key: string, kind: string?): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take refs")
	local matched = false

	for _, ref in getRefs(item) do
		if ref.key:lower() == key:lower() and (kind == nil or ref.kind == kind) then
			removeRef(item, ref.kind, ref.key)
			matched = true
		end
	end

	assert(matched, `"{id}" has no ref {key}`)
	refreshItemKind(item)
	return item
end

return detachRef
