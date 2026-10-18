local findItem = require("@root/graph/findItem")
local getContents = require("@root/graph/getContents")
local getGroup = require("@root/graph/getGroup")
local getPlacements = require("@root/graph/getPlacements")
local isGroup = require("@root/graph/isGroup")
local pruneEmptied = require("@root/graph/pruneEmptied")
local removeItem = require("@root/graph/removeItem")
local removePlacement = require("@root/graph/removePlacement")
local types = require("@root/types")

type Doc = types.Doc
type Placement = types.Placement

-- Removes a group with everything inside it. Each card goes the way `removeItem` takes it, so a note's links
-- reconnect around it, and a parent left empty disappears. Copies inside go too, and a card that also appears
-- outside the group loses only its placement here and stays where else it's shown.
local function removeGroup(doc: Doc, id: string)
	local parentId = getGroup(doc, id).parentId
	local groupIds = { [id] = true }
	local contents = getContents(doc, id)

	for _, item in contents do
		if isGroup(item) then
			groupIds[item.id] = true
		end
	end

	local placements: { Placement } = doc.placements or {}

	for index = #placements, 1, -1 do
		local placementParent = placements[index].parentId

		if placementParent and groupIds[placementParent] then
			table.remove(placements, index)
		end
	end

	doc.placements = if #placements > 0 then placements else nil

	for _, item in contents do
		if isGroup(item) or not findItem(doc, item.id) then
			continue
		end

		if #getPlacements(doc, item.id) > 1 then
			removePlacement(doc, item.id)
		else
			removeItem(doc, item.id)
		end
	end

	for index = #doc.nodes, 1, -1 do
		if groupIds[doc.nodes[index].id] then
			table.remove(doc.nodes, index)
		end
	end

	pruneEmptied(doc, parentId)
end

return removeGroup
