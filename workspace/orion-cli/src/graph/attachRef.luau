local getItem = require("@root/graph/getItem")
local isGroup = require("@root/graph/isGroup")
local refreshItemKind = require("@root/graph/refreshItemKind")
local setRef = require("@root/refs/setRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Attaches outside work to an item. The repository fills in only when the item
-- has none yet.
local function attachRef(doc: Doc, id: string, resolved: types.ResolvedRef): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take refs; attach it to an item")
	setRef(item, resolved.ref)

	if resolved.repo and item.data.repo == nil then
		item.data.repo = resolved.repo
	end

	refreshItemKind(item)
	return item
end

return attachRef
