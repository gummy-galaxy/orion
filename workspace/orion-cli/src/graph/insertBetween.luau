local getItem = require("@root/graph/getItem")
local isGroup = require("@root/graph/isGroup")
local linkItems = require("@root/graph/linkItems")
local types = require("@root/types")
local unlinkItems = require("@root/graph/unlinkItems")

type Doc = types.Doc
type Link = types.Link

-- Replaces the link between two items with two links through a third, keeping its kind.
local function insertBetween(doc: Doc, id: string, from: string, to: string)
	assert(id ~= from and id ~= to, "an item can't link to itself")

	for _, itemId in { from, id, to } do
		assert(not isGroup(getItem(doc, itemId)), `"{itemId}" is a group; link the items inside it`)
	end

	local existing: Link?

	for _, link in doc.links do
		if link.from == from and link.to == to then
			existing = link
			break
		end
	end

	assert(existing, `no link from "{from}" to "{to}"`)

	-- The label stays with the half that leaves the original source.
	unlinkItems(doc, from, to)
	linkItems(doc, from, id, existing.kind, existing.label)
	linkItems(doc, id, to, existing.kind)
end

return insertBetween
