local captureDoc = require("@root/operations/captureDoc")
local diffDocs = require("@root/operations/diffDocs")
local graph = require("@root/graph")
local operationTypes = require("@root/operations/types")
local restoreDoc = require("@root/operations/restoreDoc")
local setRawValue = require("@root/operations/setRawValue")
local types = require("@root/types")

type Doc = types.Doc
type Operation = operationTypes.Operation
type Restore = operationTypes.Restore

local handlers: { [string]: (Doc, Operation) -> () } = {}

local function required<T>(value: T?, name: string): T
	assert(value ~= nil, `an operation needs {name}`)
	return value :: T
end

handlers.setFields = function(doc: Doc, operation: Operation)
	graph.setFields(doc, required(operation.id, "id"), required(operation.fields, "fields") :: any)
end

handlers.place = function(doc: Doc, operation: Operation)
	local position = { x = required(operation.x, "x"), y = required(operation.y, "y") }
	graph.place(doc, required(operation.id, "id"), position)
end

handlers.link = function(doc: Doc, operation: Operation)
	graph.link(doc, required(operation.from, "from"), required(operation.to, "to"), operation.kind or "blocks")
end

handlers.unlink = function(doc: Doc, operation: Operation)
	graph.unlink(doc, required(operation.from, "from"), required(operation.to, "to"))
end

handlers.insert = function(doc: Doc, operation: Operation)
	graph.insertBetween(
		doc,
		required(operation.id, "id"),
		required(operation.from, "from"),
		required(operation.to, "to")
	)
end

handlers.group = function(doc: Doc, operation: Operation)
	graph.makeGroup(doc, required(operation.label, "label"), required(operation.items, "items"), operation.id)
end

handlers.ungroup = function(doc: Doc, operation: Operation)
	graph.ungroup(doc, required(operation.id, "id"))
end

handlers.remove = function(doc: Doc, operation: Operation)
	graph.remove(doc, required(operation.id, "id"), operation.reconnect)
end

handlers.removeGroup = function(doc: Doc, operation: Operation)
	graph.removeGroup(doc, required(operation.id, "id"))
end

-- Moves an item or group into another group, or to the top level when `group` is absent.
handlers.move = function(doc: Doc, operation: Operation)
	graph.move(doc, required(operation.id, "id"), operation.group)
end

handlers.tidy = function(doc: Doc, operation: Operation)
	graph.markForTidy(doc, required(operation.id, "id"))
end

-- Adds an item the app built, at the id and position it chose. The id must be free, and a group must be a group.
local function addItem(doc: Doc, operation: Operation)
	local id = required(operation.id, "id")
	assert(graph.find(doc, id) == nil, `"{id}" is already taken`)

	if operation.group then
		graph.group(doc, operation.group)
	end

	local item: types.Item = {
		id = id,
		type = required(operation.nodeType, "type"),
		position = { x = required(operation.x, "x"), y = required(operation.y, "y") },
		parentId = operation.group,
		width = operation.width,
		height = operation.height,
		data = required(operation.data, "data"),
	}

	table.insert(doc.nodes, item)
end

handlers.addCard = addItem
handlers.addNote = addItem
handlers.addImage = addItem
handlers.addGroup = addItem

-- Replaces an item's data with the data the app holds for it.
handlers.setData = function(doc: Doc, operation: Operation)
	local data = required(operation.data, "data")
	graph.get(doc, required(operation.id, "id")).data = data
end

-- Sets an item's stored size, or drops it when `clear` is set.
handlers.resize = function(doc: Doc, operation: Operation)
	local item = graph.get(doc, required(operation.id, "id"))

	if operation.clear then
		item.width = nil
		item.height = nil
		return
	end

	local width = required(operation.width, "width")
	local height = required(operation.height, "height")
	item.width = width
	item.height = height
end

handlers.setStickers = function(doc: Doc, operation: Operation)
	setRawValue(doc, "stickers", required(operation.stickers, "stickers"))
end

handlers.setStickerLoadout = function(doc: Doc, operation: Operation)
	setRawValue(doc, "stickerLoadout", required(operation.stickerLoadout, "stickerLoadout"))
end

-- Applies one operation and returns its inverse. A failed operation leaves the document as it was.
local function applyOperation(doc: Doc, operation: Operation): Restore
	local handler = handlers[operation.op]
	assert(handler, `unknown operation: {operation.op}`)
	local before = captureDoc(doc)
	local succeeded, failure = pcall(handler, doc, operation)

	if not succeeded then
		restoreDoc(doc, diffDocs(before, doc))
		error(failure, 0)
	end

	return diffDocs(before, doc)
end

return applyOperation
