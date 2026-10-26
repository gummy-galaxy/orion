local findItem = require("@root/graph/findItem")
local getAncestors = require("@root/graph/getAncestors")
local getGroup = require("@root/graph/getGroup")
local getItem = require("@root/graph/getItem")
local getSize = require("@root/graph/getSize")
local isGroup = require("@root/graph/isGroup")
local layoutTypes = require("@root/layout/types")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Box = layoutTypes.Box
type Issue = layoutTypes.Issue

-- Children store positions relative to their parent, so the canvas position
-- adds each ancestor's.
local function canvasBox(doc: Doc, item: Item): Box
	local x, y = item.position.x, item.position.y

	for _, ancestorId in getAncestors(doc, item.id) do
		local ancestor = getItem(doc, ancestorId)
		x += ancestor.position.x
		y += ancestor.position.y
	end

	local width, height = getSize(item)
	return { x = x, y = y, width = width, height = height }
end

-- Boxes that only touch along an edge don't overlap.
local function overlapOf(first: Box, second: Box): Box?
	local left = math.max(first.x, second.x)
	local top = math.max(first.y, second.y)
	local right = math.min(first.x + first.width, second.x + second.width)
	local bottom = math.min(first.y + first.height, second.y + second.height)

	if left >= right or top >= bottom then
		return nil
	end

	return { x = left, y = top, width = right - left, height = bottom - top }
end

-- Reports layout problems that can be computed from stored positions, sizes,
-- and links. With a group, only problems that involve the group or something
-- inside it are reported.
local function checkLayout(doc: Doc, groupId: string?): { Issue }
	if groupId then
		getGroup(doc, groupId)
	end

	local function inScope(id: string): boolean
		return groupId == nil or id == groupId or table.find(getAncestors(doc, id), groupId) ~= nil
	end

	local boxes: { [string]: Box } = {}

	for _, item in doc.nodes do
		boxes[item.id] = canvasBox(doc, item)
	end

	local issues: { Issue } = {}

	for index, first in doc.nodes do
		for otherIndex = index + 1, #doc.nodes do
			local second = doc.nodes[otherIndex]
			local overlap = if first.parentId == second.parentId
				then overlapOf(boxes[first.id], boxes[second.id])
				else nil

			if overlap and (inScope(first.id) or inScope(second.id)) then
				table.insert(issues, { kind = "overlap", ids = { first.id, second.id }, bounds = overlap })
			end
		end
	end

	for _, item in doc.nodes do
		local parent = if item.parentId then findItem(doc, item.parentId) else nil

		if parent and (inScope(item.id) or inScope(parent.id)) then
			local parentWidth, parentHeight = getSize(parent)
			local width, height = getSize(item)
			local x, y = item.position.x, item.position.y
			local outside = x < 0 or y < 0 or x + width > parentWidth or y + height > parentHeight

			if outside then
				table.insert(issues, { kind = "outside-group", ids = { item.id, parent.id }, bounds = boxes[item.id] })
			end
		end
	end

	for _, item in doc.nodes do
		if isGroup(item) and item.data.layout ~= nil and inScope(item.id) then
			table.insert(issues, { kind = "waiting-for-layout", ids = { item.id }, bounds = boxes[item.id] })
		end
	end

	for _, link in doc.links do
		local missing = findItem(doc, link.from) == nil or findItem(doc, link.to) == nil

		if missing and (groupId == nil or inScope(link.from) or inScope(link.to)) then
			table.insert(issues, { kind = "dangling-link", ids = { link.from, link.to } })
		end
	end

	return issues
end

return checkLayout
