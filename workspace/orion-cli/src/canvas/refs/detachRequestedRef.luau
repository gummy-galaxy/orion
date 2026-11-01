local detachRef = require("@root/canvas/refs/detachRef")
local getCurrentKey = require("@root/sources/github/refs/getCurrentKey")
local getItem = require("@root/canvas/items/getItem")
local getRefs = require("@root/canvas/refs/getRefs")
local isGroup = require("@root/canvas/groups/isGroup")
local resolveRef = require("@root/sources/resolveRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Takes a ref off an item by the key orion node show lists. A URL or source:key
-- that isn't a key on the item resolves the way --ref does, and then has to
-- match that ref's kind too.
local function detachRequestedRef(doc: Doc, id: string, input: string): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take refs")

	local current = getCurrentKey(doc, input)

	for _, ref in getRefs(item) do
		if ref.key:lower() == input:lower() or ref.key:lower() == current:lower() then
			return detachRef(doc, id, ref.key)
		end
	end

	assert(input:find(":"), `"{id}" has no ref {input}`)
	local resolved = resolveRef(input, doc.settings.sources)
	return detachRef(doc, id, getCurrentKey(doc, resolved.ref.key), resolved.ref.kind)
end

return detachRequestedRef
