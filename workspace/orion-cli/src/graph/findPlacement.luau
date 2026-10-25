local freeSpotBelow = require("@root/graph/freeSpotBelow")
local geometry = require("@root/geometry")
local getGap = require("@root/graph/getGap")
local getHeaderHeight = require("@root/graph/getHeaderHeight")
local getItem = require("@root/graph/getItem")
local getNextSlot = require("@root/graph/getNextSlot")
local getSize = require("@root/graph/getSize")
local overlapsSibling = require("@root/graph/overlapsSibling")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Position = types.Position

-- Two numbers this close sit on the same row, so rounding in a stored position doesn't split a row.
local ROW_TOLERANCE = 1

-- With no neighbor to sit beside, the next spot in reading order after a group's last row, wrapping to a new row
-- below everything at the group's current width, so an unlinked card never widens it.
local function findSpotAfterContent(doc: Doc, item: Item, siblings: { Item }, skip: { [string]: boolean }): Position
	local parentId = item.parentId :: string
	local group = getItem(doc, parentId)

	if #siblings == 0 then
		return { x = geometry.GROUP_PADDING, y = getHeaderHeight(group) }
	end

	local width, height = getSize(item)
	local gap = getGap(parentId)
	local left = math.huge
	local right = -math.huge
	local bottom = -math.huge
	local lastRow = -math.huge

	for _, sibling in siblings do
		local siblingWidth, siblingHeight = getSize(sibling)
		left = math.min(left, sibling.position.x)
		right = math.max(right, sibling.position.x + siblingWidth)
		bottom = math.max(bottom, sibling.position.y + siblingHeight)
		lastRow = math.max(lastRow, sibling.position.y)
	end

	local rowRight = -math.huge

	for _, sibling in siblings do
		if math.abs(sibling.position.y - lastRow) < ROW_TOLERANCE then
			rowRight = math.max(rowRight, sibling.position.x + getSize(sibling))
		end
	end

	local limit = math.max(right, (group.width or 0) - geometry.GROUP_PADDING)
	local slot = { x = rowRight + gap.x, y = lastRow }

	if slot.x + width <= limit and not overlapsSibling(doc, parentId, slot, width, height, skip) then
		return slot
	end

	return { x = left, y = bottom + gap.y }
end

-- How far right an item reaches.
local function getReach(item: Item): number
	return item.position.x + getSize(item)
end

-- How far left an item starts, as a score where higher is further left.
local function getLeftness(item: Item): number
	return -item.position.x
end

-- Whether `candidate` beats `incumbent` on `score`, higher winning. A tie goes to the higher of the two, so the choice
-- doesn't depend on link order.
local function beats(candidate: Item, incumbent: Item?, score: (Item) -> number): boolean
	if incumbent == nil then
		return true
	end

	local candidateScore = score(candidate)
	local incumbentScore = score(incumbent)
	return candidateScore > incumbentScore
		or (candidateScore == incumbentScore and candidate.position.y < incumbent.position.y)
end

--[[
	Where a new item lands among its parent's children. Only blocking links to siblings count, since they're the ones
	with a direction:

	1. One gap right of the card that blocks it, on that card's row. With several, the one reaching furthest right.
	2. Otherwise one gap left of the leftmost card it blocks, unless that crosses the group's left padding.
	3. From either spot, down a row at a time to the first one free.
	4. With neither, in a group, the next spot after the last row without widening it; at the top level, right of
	   everything, as before.

	Nothing already placed moves. The item itself and the ids in `unplaced` don't count as siblings, so items added
	together can be placed one by one once their links are known.
]]
local function findPlacement(doc: Doc, item: Item, unplaced: { [string]: boolean }?): Position
	local parentId = item.parentId
	local skip: { [string]: boolean } = if unplaced then table.clone(unplaced) else {}
	skip[item.id] = true

	local siblings: { Item } = {}
	local byId: { [string]: Item } = {}

	for _, node in doc.nodes do
		if node.parentId == parentId and not skip[node.id] then
			table.insert(siblings, node)
			byId[node.id] = node
		end
	end

	local predecessor: Item? = nil
	local successor: Item? = nil

	for _, link in doc.links do
		if link.kind ~= "blocks" then
			continue
		end

		local from = byId[link.from]
		local to = byId[link.to]

		if link.to == item.id and from then
			if beats(from, predecessor, getReach) then
				predecessor = from
			end
		elseif link.from == item.id and to then
			if beats(to, successor, getLeftness) then
				successor = to
			end
		end
	end

	local width, height = getSize(item)
	local gap = getGap(parentId)

	if predecessor then
		local start = { x = getReach(predecessor) + gap.x, y = predecessor.position.y }
		return freeSpotBelow(doc, parentId, start, width, height, skip)
	end

	if successor then
		local start = { x = successor.position.x - gap.x - width, y = successor.position.y }

		if parentId == nil or start.x >= geometry.GROUP_PADDING then
			return freeSpotBelow(doc, parentId, start, width, height, skip)
		end
	end

	if parentId == nil then
		return getNextSlot(doc, nil, skip)
	end

	return findSpotAfterContent(doc, item, siblings, skip)
end

return findPlacement
