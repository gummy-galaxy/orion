local addItem = require("@root/graph/addItem")
local addNote = require("@root/graph/addNote")
local applyTypes = require("@root/apply/types")
local attachRef = require("@root/graph/attachRef")
local detachRequestedRef = require("@root/graph/detachRequestedRef")
local getErrorCode = require("@root/getErrorCode")
local getErrorText = require("@root/getErrorText")
local insertBetween = require("@root/graph/insertBetween")
local linkItems = require("@root/graph/linkItems")
local makeGroup = require("@root/graph/makeGroup")
local markForTidy = require("@root/graph/markForTidy")
local moveItem = require("@root/graph/moveItem")
local placeTogether = require("@root/graph/placeTogether")
local raiseFailure = require("@root/raiseFailure")
local removeGroup = require("@root/graph/removeGroup")
local removeItem = require("@root/graph/removeItem")
local resolveRef = require("@root/adapters/resolveRef")
local setFields = require("@root/graph/setFields")
local types = require("@root/types")
local ungroup = require("@root/graph/ungroup")
local unlinkItems = require("@root/graph/unlinkItems")

type Doc = types.Doc
type Operation = applyTypes.Operation

-- Handles name the cards, notes, and groups a plan creates, so later steps can
-- refer to them.
type Handles = { [string]: string }

-- A step that adds a card or note records its id in `added`, so the plan can
-- place it once every link is in.
type Handler = (Doc, Operation, Handles, { string }) -> ()

-- "@name" is a handle declared by an earlier step. Any other value is an id
-- already on the canvas.
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

handlers.addCard = function(doc: Doc, operation: Operation, handles: Handles, added: { string })
	local options = table.clone(operation.fields or {}) :: any
	options.group = resolveOptional(handles, operation.group)
	options.after = resolveOptional(handles, operation.after)
	options.before = resolveOptional(handles, operation.before)
	local item = addItem(doc, required(operation.label, "label"), options)

	if operation.ref then
		attachRef(doc, item.id, resolveRef(operation.ref, doc.settings.sources))
	end

	declare(handles, operation.handle, item.id)
	table.insert(added, item.id)
end

handlers.addNote = function(doc: Doc, operation: Operation, handles: Handles, added: { string })
	local note = addNote(doc, required(operation.text, "text"), {
		group = resolveOptional(handles, operation.group),
		after = resolveOptional(handles, operation.after),
		before = resolveOptional(handles, operation.before),
	})

	declare(handles, operation.handle, note.id)
	table.insert(added, note.id)
end

handlers.group = function(doc: Doc, operation: Operation, handles: Handles)
	local ids: { string } = {}

	for _, id in required(operation.items, "items") do
		table.insert(ids, resolve(handles, id))
	end

	local made = makeGroup(doc, required(operation.label, "label"), ids)
	declare(handles, operation.handle, made.id)
end

handlers.setFields = function(doc: Doc, operation: Operation, handles: Handles)
	setFields(doc, resolve(handles, required(operation.id, "id")), required(operation.fields, "fields") :: any)
end

handlers.link = function(doc: Doc, operation: Operation, handles: Handles)
	local from = resolve(handles, required(operation.from, "from"))
	local to = resolve(handles, required(operation.to, "to"))
	linkItems(doc, from, to, operation.kind or "blocks", operation.label)
end

handlers.unlink = function(doc: Doc, operation: Operation, handles: Handles)
	local from = resolve(handles, required(operation.from, "from"))
	local to = resolve(handles, required(operation.to, "to"))
	unlinkItems(doc, from, to)
end

handlers.insert = function(doc: Doc, operation: Operation, handles: Handles)
	local id = resolve(handles, required(operation.id, "id"))
	local from = resolve(handles, required(operation.from, "from"))
	local to = resolve(handles, required(operation.to, "to"))
	insertBetween(doc, id, from, to)
end

-- A move without a group goes to the top level.
handlers.move = function(doc: Doc, operation: Operation, handles: Handles)
	moveItem(doc, resolve(handles, required(operation.id, "id")), resolveOptional(handles, operation.group))
end

handlers.remove = function(doc: Doc, operation: Operation, handles: Handles)
	removeItem(doc, resolve(handles, required(operation.id, "id")), operation.reconnect)
end

handlers.removeGroup = function(doc: Doc, operation: Operation, handles: Handles)
	removeGroup(doc, resolve(handles, required(operation.id, "id")))
end

handlers.ungroup = function(doc: Doc, operation: Operation, handles: Handles)
	ungroup(doc, resolve(handles, required(operation.id, "id")))
end

handlers.tidy = function(doc: Doc, operation: Operation, handles: Handles)
	markForTidy(doc, resolve(handles, required(operation.id, "id")))
end

-- Attaches a ref the way --ref does, resolving it against the canvas's sources.
-- It changes only Orion's record of the card, never the source.
handlers.attachRef = function(doc: Doc, operation: Operation, handles: Handles)
	local id = resolve(handles, required(operation.id, "id"))
	attachRef(doc, id, resolveRef(required(operation.ref, "ref"), doc.settings.sources))
end

-- Takes a ref off by its key, URL, or source:key, as orion ref remove does.
handlers.detachRef = function(doc: Doc, operation: Operation, handles: Handles)
	detachRequestedRef(doc, resolve(handles, required(operation.id, "id")), required(operation.ref, "ref"))
end

-- Applies the steps in order to the document. A step that fails raises an error
-- naming its position. The caller's transaction then writes nothing, so a plan
-- lands whole or not at all. Cards and notes the plan adds are placed after its
-- last step, so links made later in the plan count. Returns the id each
-- declared handle got.
local function applyOperations(doc: Doc, operations: { Operation }): Handles
	local handles: Handles = {}
	local added: { string } = {}

	for index, operation in operations do
		local handler = assert(handlers[operation.op], `unknown operation: {operation.op}`)
		local succeeded, failure = pcall(handler, doc, operation, handles, added)

		if not succeeded then
			local message = `operation {index} ({operation.op}): {getErrorText(failure)}`
			local code = getErrorCode(failure)

			if code then
				raiseFailure(code, message)
			end

			error(message, 0)
		end
	end

	placeTogether(doc, added)
	return handles
end

return applyOperations
