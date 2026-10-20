local json = require("@std/json")

local createId = require("@root/graph/createId")
local getGroup = require("@root/graph/getGroup")
local getItem = require("@root/graph/getItem")
local getNextSlot = require("@root/graph/getNextSlot")
local getSize = require("@root/graph/getSize")
local graphTypes = require("@root/graph/types")
local insertBetween = require("@root/graph/insertBetween")
local linkItems = require("@root/graph/linkItems")
local sizes = require("@root/graph/sizes")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type NoteOptions = graphTypes.NoteOptions
type Position = types.Position

local function overlapsSibling(doc: Doc, parentId: string?, position: Position, width: number, height: number): boolean
	local margin = sizes.ITEM_GAP / 2

	for _, item in doc.nodes do
		if item.parentId == parentId then
			local itemWidth, itemHeight = getSize(item)

			if
				position.x < item.position.x + itemWidth + margin
				and item.position.x < position.x + width + margin
				and position.y < item.position.y + itemHeight + margin
				and item.position.y < position.y + height + margin
			then
				return true
			end
		end
	end

	return false
end

-- The first spot at or below a preferred one that no sibling covers.
local function freeSpotBelow(doc: Doc, parentId: string?, preferred: Position): Position
	local position = { x = preferred.x, y = preferred.y }

	while overlapsSibling(doc, parentId, position, sizes.TASK_WIDTH, sizes.TASK_HEIGHT) do
		position.y += sizes.TASK_HEIGHT + sizes.ITEM_GAP
	end

	return position
end

-- Adds a note. An existing link keeps its kind when the note splits it.
local function addNote(doc: Doc, text: string, options: NoteOptions): Item
	assert(text ~= "", "a note needs text")
	local after = if options.after then getItem(doc, options.after) else nil
	local before = if options.before then getItem(doc, options.before) else nil
	local parent = options.group

	if parent then
		getGroup(doc, parent)
	elseif after then
		parent = after.parentId
	elseif before then
		parent = before.parentId
	end

	local hasExistingLink = false

	if after and before then
		for _, link in doc.links do
			if link.from == after.id and link.to == before.id then
				hasExistingLink = true
				break
			end
		end
	end

	local position = getNextSlot(doc, parent)

	if after and after.parentId == parent then
		position = freeSpotBelow(doc, parent, {
			x = after.position.x + sizes.TASK_WIDTH + sizes.ITEM_GAP,
			y = after.position.y + sizes.TASK_HEIGHT + sizes.GROUP_PADDING,
		})
	end

	local note: Item = {
		id = createId(),
		type = "task",
		position = position,
		parentId = parent,
		data = json.object({ kind = "task", label = text, itemKind = "note", status = "todo" }),
	}
	table.insert(doc.nodes, note)

	if after and before and hasExistingLink then
		insertBetween(doc, note.id, after.id, before.id)
	else
		if after then
			linkItems(doc, after.id, note.id, "blocks")
		end

		if before then
			linkItems(doc, note.id, before.id, "blocks")
		end
	end

	return note
end

return addNote
