local applyTypes = require("@root/apply/types")
local getErrorText = require("@root/getErrorText")
local graph = require("@root/graph")
local resolveRef = require("@root/adapters/resolveRef")
local types = require("@root/types")

type Doc = types.Doc
type Operation = applyTypes.Operation

-- Handles name the cards, notes, and groups a plan creates, so later steps can refer to them.
type Handles = { [string]: string }

type Handler = (Doc, Operation, Handles) -> ()

-- "@name" is a handle declared by an earlier step. Any other value is an id already on the canvas.
local function resolve(handles: Handles, value: string): string
	if value:sub(1, 1) ~= "@" then
		return value
	end

	return (assert(handles[value:sub(2)], `unknown handle {value}; declare it in an earlier step`))
end

local function resolveOptional(handles: Handles, value: string?): string?
	return if value then resolve(handles, value) else nil
end

local function required<T>(value: T?, name: string): T
	return (assert(value, `a step needs {name}`))
end

local function declare(handles: Handles, handle: string?, id: string)
	if handle then
		assert(handles[handle] == nil, `handle @{handle} is already declared`)
		handles[handle] = id
	end
end

local handlers: { [string]: Handler } = {}

handlers.addCard = function(doc: Doc, operation: Operation, handles: Handles)
	local options = table.clone(operation.fields or {}) :: any
	options.group = resolveOptional(handles, operation.group)
	local item = graph.addItem(doc, required(operation.label, "label"), options)

	if operation.ref then
		graph.attachRef(doc, item.id, resolveRef(operation.ref, doc.settings.sources))
	end

	declare(handles, operation.handle, item.id)
end

handlers.addNote = function(doc: Doc, operation: Operation, handles: Handles)
	local note = graph.addNote(doc, required(operation.text, "text"), {
		group = resolveOptional(handles, operation.group),
		after = resolveOptional(handles, operation.after),
		before = resolveOptional(handles, operation.before),
	})

	declare(handles, operation.handle, note.id)
end

handlers.group = function(doc: Doc, operation: Operation, handles: Handles)
	local ids: { string } = {}

	for _, id in required(operation.items, "items") do
		table.insert(ids, resolve(handles, id))
	end

	local made = graph.makeGroup(doc, required(operation.label, "label"), ids)
	declare(handles, operation.handle, made.id)
end

handlers.setFields = function(doc: Doc, operation: Operation, handles: Handles)
	graph.setFields(doc, resolve(handles, required(operation.id, "id")), required(operation.fields, "fields") :: any)
end

handlers.link = function(doc: Doc, operation: Operation, handles: Handles)
	local from = resolve(handles, required(operation.from, "from"))
	local to = resolve(handles, required(operation.to, "to"))
	graph.link(doc, from, to, operation.kind or "blocks")
end

handlers.unlink = function(doc: Doc, operation: Operation, handles: Handles)
	local from = resolve(handles, required(operation.from, "from"))
	local to = resolve(handles, required(operation.to, "to"))
	graph.unlink(doc, from, to)
end

handlers.insert = function(doc: Doc, operation: Operation, handles: Handles)
	local id = resolve(handles, required(operation.id, "id"))
	local from = resolve(handles, required(operation.from, "from"))
	local to = resolve(handles, required(operation.to, "to"))
	graph.insertBetween(doc, id, from, to)
end

-- A move without a group goes to the top level.
handlers.move = function(doc: Doc, operation: Operation, handles: Handles)
	graph.move(doc, resolve(handles, required(operation.id, "id")), resolveOptional(handles, operation.group))
end

handlers.remove = function(doc: Doc, operation: Operation, handles: Handles)
	graph.remove(doc, resolve(handles, required(operation.id, "id")), operation.reconnect)
end

handlers.removeGroup = function(doc: Doc, operation: Operation, handles: Handles)
	graph.removeGroup(doc, resolve(handles, required(operation.id, "id")))
end

handlers.ungroup = function(doc: Doc, operation: Operation, handles: Handles)
	graph.ungroup(doc, resolve(handles, required(operation.id, "id")))
end

handlers.tidy = function(doc: Doc, operation: Operation, handles: Handles)
	graph.markForTidy(doc, resolve(handles, required(operation.id, "id")))
end

-- Applies the steps in order to the document. A step that fails raises an error naming its position. The caller's
-- transaction then writes nothing, so a plan lands whole or not at all. Returns the id each declared handle got.
local function applyOperations(doc: Doc, operations: { Operation }): Handles
	local handles: Handles = {}

	for index, operation in operations do
		local handler = assert(handlers[operation.op], `unknown operation: {operation.op}`)
		local succeeded, failure = pcall(handler, doc, operation, handles)

		if not succeeded then
			error(`operation {index} ({operation.op}): {getErrorText(failure)}`, 0)
		end
	end

	return handles
end

return applyOperations
