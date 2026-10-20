local json = require("@std/json")

local createId = require("@root/graph/createId")
local findItem = require("@root/graph/findItem")
local geometry = require("@root/geometry")
local getItem = require("@root/graph/getItem")
local getSize = require("@root/graph/getSize")
local markForRefit = require("@root/graph/markForRefit")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- Wraps items that share a parent in a new group, keeping their arrangement. An id the caller picks must be free.
local function makeGroup(doc: Doc, label: string, ids: { string }, groupId: string?): Item
	assert(label ~= "", "a group needs a name")
	assert(#ids > 0, "a group needs at least one item")
	assert(groupId == nil or findItem(doc, groupId) == nil, `"{groupId or ""}" is already taken`)
	local members: { Item } = {}

	for _, id in ids do
		table.insert(members, (getItem(doc, id)))
	end

	local parent = members[1].parentId

	for _, member in members do
		assert(member.parentId == parent, "grouped items must share a parent; move them first")
	end

	local minimumX, minimumY, maximumX, maximumY = math.huge, math.huge, -math.huge, -math.huge

	for _, member in members do
		local width, height = getSize(member)
		minimumX = math.min(minimumX, member.position.x)
		minimumY = math.min(minimumY, member.position.y)
		maximumX = math.max(maximumX, member.position.x + width)
		maximumY = math.max(maximumY, member.position.y + height)
	end

	local origin = { x = minimumX - geometry.GROUP_PADDING, y = minimumY - geometry.GROUP_HEADER_HEIGHT }
	local group: Item = {
		id = groupId or createId(),
		type = "cluster",
		position = origin,
		parentId = parent,
		width = maximumX - minimumX + geometry.GROUP_PADDING * 2,
		height = maximumY - minimumY + geometry.GROUP_HEADER_HEIGHT + geometry.GROUP_PADDING,
		data = json.object({ kind = "cluster", label = label }),
	}

	for _, member in members do
		member.parentId = group.id
		member.position = { x = member.position.x - origin.x, y = member.position.y - origin.y }
	end

	markForRefit(group)
	table.insert(doc.nodes, group)
	return group
end

return makeGroup
