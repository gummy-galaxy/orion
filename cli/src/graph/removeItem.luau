local checkReconnect = require("@root/graph/checkReconnect")
local getItem = require("@root/graph/getItem")
local isGroup = require("@root/graph/isGroup")
local isNote = require("@root/graph/isNote")
local linkItems = require("@root/graph/linkItems")
local pruneEmptied = require("@root/graph/pruneEmptied")
local types = require("@root/types")

type Doc = types.Doc
type Placement = types.Placement
type Link = types.Link

-- A note's incoming and outgoing links are reconnected so nothing loses its blocker. Every placement of the item goes
-- with it, and so does any group that leaves empty.
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

	local placements: { Placement } = doc.placements or {}
	local emptied: { string } = {}

	for index = #placements, 1, -1 do
		if placements[index].node == id then
			local placementParent = placements[index].parentId

			if placementParent then
				table.insert(emptied, placementParent)
			end

			table.remove(placements, index)
		end
	end

	doc.placements = if #placements > 0 then placements else nil
	pruneEmptied(doc, parentId)

	for _, groupId in emptied do
		pruneEmptied(doc, groupId)
	end
end

return removeItem
