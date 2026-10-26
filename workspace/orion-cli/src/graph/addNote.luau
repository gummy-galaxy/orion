local json = require("@std/json")

local createId = require("@root/graph/createId")
local findPlacement = require("@root/graph/findPlacement")
local getNeighborGroup = require("@root/graph/getNeighborGroup")
local graphTypes = require("@root/graph/types")
local linkNeighbors = require("@root/graph/linkNeighbors")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type NoteOptions = graphTypes.NoteOptions

-- Adds a note beside the items it links to. An existing link keeps its kind
-- when the note splits it.
local function addNote(doc: Doc, text: string, options: NoteOptions): Item
	assert(text ~= "", "a note needs text")
	local parent = getNeighborGroup(doc, options.group, options.after, options.before)

	local note: Item = {
		id = createId(),
		type = "task",
		position = { x = 0, y = 0 },
		parentId = parent,
		data = json.object({ kind = "task", label = text, itemKind = "note", status = "todo" }),
	}
	table.insert(doc.nodes, note)
	linkNeighbors(doc, note.id, options.after, options.before)
	note.position = findPlacement(doc, note)

	return note
end

return addNote
