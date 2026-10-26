local createId = require("@root/graph/createId")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Placement = types.Placement

-- An unplaced node reads as sitting at the origin with no group, so a change
-- that moved it anywhere else placed it.
local function isStillUnplaced(item: Item): boolean
	return item.unplaced == true and item.parentId == nil and item.position.x == 0 and item.position.y == 0
end

--[[
	Brings the document's placements in line with its nodes before a write.
	Each node's own placement, the one its `placement` names, takes the node's
	position and group and comes first among the node's placements. A node
	without one gets one, under the id it remembers when a change put it back,
	unless it's still unplaced. Placements of nodes that are gone go with them,
	and the rest follow their nodes' order, so putting a node back restores its
	placement as it was.
]]
local function syncPlacements(doc: Doc)
	local byNode: { [string]: { Placement } } = {}
	local used: { [string]: boolean } = {}
	local placements: { Placement } = {}

	for _, placement in doc.placements do
		byNode[placement.node] = byNode[placement.node] or {}
		table.insert(byNode[placement.node], placement)
		used[placement.id] = true
	end

	for _, item in doc.nodes do
		local others = byNode[item.id] or {}
		local own: Placement? = nil

		for index, placement in others do
			if placement.id == item.placement then
				own = table.remove(others, index)
				break
			end
		end

		own = own or table.remove(others, 1)

		-- A node copied from another remembers that node's placement, so the
		-- id it remembers is only reused while no placement has it.
		if not own and not isStillUnplaced(item) then
			local id = if item.placement and not used[item.placement] then item.placement else createId()
			local placement: Placement = { id = id, node = item.id, position = item.position }
			own = placement
			used[id] = true
		end

		if own then
			own.parentId = item.parentId
			own.position = { x = item.position.x, y = item.position.y }
			item.placement = own.id
			item.unplaced = nil
			table.insert(placements, own)
		end

		for _, placement in others do
			table.insert(placements, placement)
		end
	end

	doc.placements = placements
end

return syncPlacements
