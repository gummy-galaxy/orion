local checkReconnect = require("@root/canvas/links/checkReconnect")
local getItem = require("@root/canvas/items/getItem")
local isGroup = require("@root/canvas/groups/isGroup")
local isNote = require("@root/canvas/items/isNote")
local linkItems = require("@root/canvas/links/linkItems")
local pruneEmptied = require("@root/canvas/groups/pruneEmptied")
local types = require("@root/types")

type Doc = types.Doc
type Link = types.Link

-- A note's incoming and outgoing links are reconnected so nothing loses its
-- blocker.
local function removeItem(doc: Doc, id: string, reconnect: boolean?)
	local item = getItem(doc, id)
	assert(not isGroup(item), `"{id}" is a group; use group ungroup or group remove instead`)
	local parentId = item.parentId

	if reconnect then
		checkReconnect(doc, id)
	end

	local incomingLinks: { Link } = {}
	local outgoingLinks: { Link } = {}

	for index = #doc.links, 1, -1 do
		local link = doc.links[index]

		if link.to == id then
			table.insert(incomingLinks, link)
			table.remove(doc.links, index)
		elseif link.from == id then
			table.insert(outgoingLinks, link)
			table.remove(doc.links, index)
		end
	end

	if isNote(item) or reconnect then
		for _, incomingLink in incomingLinks do
			for _, outgoingLink in outgoingLinks do
				linkItems(
					doc,
					incomingLink.from,
					outgoingLink.to,
					if incomingLink.kind == "blocks" and outgoingLink.kind == "blocks" then "blocks" else "related"
				)
			end
		end
	end

	for index, other in doc.nodes do
		if other.id == id then
			table.remove(doc.nodes, index)
			break
		end
	end

	pruneEmptied(doc, parentId)
end

return removeItem
