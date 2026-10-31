local createId = require("@root/common/createId")
local getItem = require("@root/canvas/items/getItem")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Doc = types.Doc
type Link = types.Link

-- Links two items. A label names what the link carries, like "HTTP" in a system
-- diagram; an empty one clears it, and leaving it out keeps the label an
-- existing link already has.
local function linkItems(doc: Doc, from: string, to: string, kind: string, label: string?): Link
	assert(from ~= to, "an item can't link to itself")

	for _, id in { from, to } do
		assert(not isGroup(getItem(doc, id)), `"{id}" is a group; link the items inside it`)
	end

	local text = if label then label:match("^%s*(.-)%s*$") else nil

	for _, link in doc.links do
		if link.from == from and link.to == to then
			link.kind = kind

			if text then
				link.label = if text == "" then nil else text
			end

			return link
		end
	end

	local link: Link = { id = createId(), from = from, to = to, kind = kind }

	if text and text ~= "" then
		link.label = text
	end

	table.insert(doc.links, link)
	return link
end

return linkItems
