local findRepository = require("@root/sources/github/repositories/findRepository")
local getItem = require("@root/canvas/items/getItem")
local identifyRef = require("@root/sources/github/refs/identifyRef")
local isGroup = require("@root/canvas/groups/isGroup")
local refreshItemKind = require("@root/canvas/items/refreshItemKind")
local setRef = require("@root/canvas/refs/setRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Attaches outside work to an item. The repository fills in only when the item
-- has none yet.
local function attachRef(doc: Doc, id: string, resolved: types.ResolvedRef): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take refs; attach it to an item")
	setRef(item, identifyRef(doc, resolved.ref))
	local found = if resolved.repo then findRepository(doc, resolved.repo) else nil

	if resolved.repo and item.data.repo == nil then
		item.data.repo = if found then found.name else resolved.repo
	end

	refreshItemKind(item)
	return item
end

return attachRef
