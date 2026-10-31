local captureDoc = require("@root/canvas/operations/captureDoc")
local closeChain = require("@root/canvas/links/closeChain")
local closeOut = require("@root/canvas/items/closeOut")
local diffDocs = require("@root/canvas/operations/diffDocs")
local findItem = require("@root/canvas/items/findItem")
local getGroup = require("@root/canvas/groups/getGroup")
local getItem = require("@root/canvas/items/getItem")
local graphTypes = require("@root/canvas/types")
local insertBetween = require("@root/canvas/links/insertBetween")
local json = require("@std/json")
local linkItems = require("@root/canvas/links/linkItems")
local makeGroup = require("@root/canvas/groups/makeGroup")
local markForTidy = require("@root/canvas/placement/markForTidy")
local moveItem = require("@root/canvas/placement/moveItem")
local operationTypes = require("@root/canvas/operations/types")
local placeItem = require("@root/canvas/placement/placeItem")
local removeGroup = require("@root/canvas/groups/removeGroup")
local removeItem = require("@root/canvas/items/removeItem")
local restoreDoc = require("@root/canvas/operations/restoreDoc")
local setFields = require("@root/canvas/items/setFields")
local setPullRequest = require("@root/canvas/items/setPullRequest")
local setRawValue = require("@root/canvas/operations/setRawValue")
local types = require("@root/types")
local ungroup = require("@root/canvas/groups/ungroup")
local unlinkItems = require("@root/canvas/links/unlinkItems")

type Doc = types.Doc
type Operation = operationTypes.Operation
type Restore = operationTypes.Restore

local handlers: { [string]: (Doc, Operation) -> () } = {}
-- Operations that answer with what they did, which goes back to the client with
-- the change.
local answering: { [string]: (Doc, Operation) -> json.Value } = {}

local function required<T>(value: T?, name: string): T
	assert(value ~= nil, `an operation needs {name}`)
	return value :: T
end

-- Sets fields with the CLI's rules. `pr` points a card at a pull request in its
-- repository, or takes it off when empty.
handlers.setFields = function(doc: Doc, operation: Operation)
	local id = required(operation.id, "id")
	local fields = table.clone(required(operation.fields, "fields"))
	local pr = fields.pr
	fields.pr = nil
	setFields(doc, id, fields :: any)

	if pr ~= nil then
		setPullRequest(doc, id, if pr == "" then nil else pr :: number)
	end
end

handlers.place = function(doc: Doc, operation: Operation)
	local position = { x = required(operation.x, "x"), y = required(operation.y, "y") }
	placeItem(doc, required(operation.id, "id"), position)
end

handlers.link = function(doc: Doc, operation: Operation)
	linkItems(
		doc,
		required(operation.from, "from"),
		required(operation.to, "to"),
		operation.kind or "blocks",
		operation.label
	)
end

handlers.unlink = function(doc: Doc, operation: Operation)
	unlinkItems(doc, required(operation.from, "from"), required(operation.to, "to"))
end

handlers.insert = function(doc: Doc, operation: Operation)
	insertBetween(doc, required(operation.id, "id"), required(operation.from, "from"), required(operation.to, "to"))
end

handlers.group = function(doc: Doc, operation: Operation)
	makeGroup(doc, required(operation.label, "label"), required(operation.items, "items"), operation.id)
end

handlers.ungroup = function(doc: Doc, operation: Operation)
	ungroup(doc, required(operation.id, "id"))
end

handlers.remove = function(doc: Doc, operation: Operation)
	removeItem(doc, required(operation.id, "id"), operation.reconnect)
end

handlers.removeGroup = function(doc: Doc, operation: Operation)
	removeGroup(doc, required(operation.id, "id"))
end

-- Moves an item or group into another group, or to the top level when `group`
-- is absent.
handlers.move = function(doc: Doc, operation: Operation)
	moveItem(doc, required(operation.id, "id"), operation.group)
end

handlers.tidy = function(doc: Doc, operation: Operation)
	markForTidy(doc, required(operation.id, "id"))
end

-- Closes out one card finished in the app, leaving the cards chained to it
-- waiting.
handlers.closeOut = function(doc: Doc, operation: Operation)
	closeOut(doc, required(operation.id, "id"))
end

-- Closes out a finished card and its chain, and answers with each card closed
-- and passed, with its hops from the card.
answering.chainClose = function(doc: Doc, operation: Operation): json.Value
	local result = closeChain(doc, required(operation.id, "id"))
	local function steps(list: { graphTypes.ChainStep }): json.Array
		local array: json.Array = {}

		for _, step in list do
			table.insert(array, json.object({ id = step.id, hops = step.hops }))
		end

		return array
	end

	return json.object({ closed = steps(result.closed), passed = steps(result.passed) })
end

-- Adds an item the app built, at the id and position it chose. The id must be
-- free, and a group must be a group.
local function addItem(doc: Doc, operation: Operation)
	local id = required(operation.id, "id")
	assert(findItem(doc, id) == nil, `"{id}" is already taken`)

	if operation.group then
		getGroup(doc, operation.group)
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

	-- A card is added as it is, so one pasted from a card still waiting to be
	-- closed out doesn't wait too.
	item.data.celebrate = nil
	table.insert(doc.nodes, item)
end

handlers.addCard = addItem
handlers.addNote = addItem
handlers.addImage = addItem
handlers.addGroup = addItem

-- Replaces a group's or image's data with the data the app holds for it. Cards
-- change through setFields, so no client skips their field rules.
handlers.setData = function(doc: Doc, operation: Operation)
	local data = required(operation.data, "data")
	local id = required(operation.id, "id")
	local item = getItem(doc, id)
	assert(item.type ~= "task", `"{id}" is a card; change its fields with setFields`)
	item.data = data
end

-- Sets an item's stored size, or drops it when `clear` is set.
handlers.resize = function(doc: Doc, operation: Operation)
	local item = getItem(doc, required(operation.id, "id"))

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

-- Applies one operation and returns its inverse, and what the operation
-- answered, if anything. A failed operation leaves the document as it was.
local function applyOperation(doc: Doc, operation: Operation): (Restore, json.Value?)
	local handler = handlers[operation.op]
	local answerer = answering[operation.op]
	assert(handler or answerer, `unknown operation: {operation.op}`)
	local before = captureDoc(doc)
	local answer: json.Value? = nil
	local succeeded, failure = pcall(function()
		if answerer then
			answer = answerer(doc, operation)
		else
			handler(doc, operation)
		end
	end)

	if not succeeded then
		restoreDoc(doc, diffDocs(before, doc))
		error(failure, 0)
	end

	return diffDocs(before, doc), answer
end

return applyOperation
