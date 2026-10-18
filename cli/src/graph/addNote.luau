local json = require("@std/json")

local geometry = require("@root/geometry")
local getGroup = require("@root/graph/getGroup")
local getItem = require("@root/graph/getItem")
local getNextSlot = require("@root/graph/getNextSlot")
local getSize = require("@root/graph/getSize")
local getUniqueId = require("@root/graph/getUniqueId")
local graphTypes = require("@root/graph/types")
local insertBetween = require("@root/graph/insertBetween")
local linkItems = require("@root/graph/linkItems")
local slugify = require("@root/slugify")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type NoteOptions = graphTypes.NoteOptions
type Position = types.Position

-- The app's spacing for the level a note lands on.
local function getGap(parentId: string?)
	return if parentId then geometry.GAP.inner else geometry.GAP.top
end

local function overlapsSibling(doc: Doc, parentId: string?, position: Position, width: number, height: number): boolean
	local margin = getGap(parentId).y

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

-- The first spot at or below a preferred one that no sibling covers, for a note of the given size.
local function freeSpotBelow(doc: Doc, parentId: string?, preferred: Position, width: number, height: number): Position
	local position = { x = preferred.x, y = preferred.y }

	while overlapsSibling(doc, parentId, position, width, height) do
		position.y += height + getGap(parentId).y
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

	local note: Item = {
		id = getUniqueId(doc, `note-{slugify(text, 24)}`),
		type = "task",
		position = getNextSlot(doc, parent),
		parentId = parent,
		data = json.object({ kind = "task", label = text, itemKind = "note", status = "todo" }),
	}

	if after and after.parentId == parent then
		local afterWidth, afterHeight = getSize(after)
		local width, height = getSize(note)
		local gap = getGap(parent)
		note.position = freeSpotBelow(doc, parent, {
			x = after.position.x + afterWidth + gap.x,
			y = after.position.y + afterHeight + gap.y,
		}, width, height)
	end

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
