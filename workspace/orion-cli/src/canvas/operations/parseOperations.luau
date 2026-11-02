local getErrorText = require("@root/common/errors/getErrorText")
local getStringField = require("@root/common/getStringField")
local json = require("@std/json")
local operationTypes = require("@root/canvas/operations/types")

type Operation = operationTypes.Operation

-- The edits a client may send, and the fields each one reads. Anything else is
-- refused before the document is touched.
local FIELD_TYPES: { [string]: string } = {
	label = "string",
	status = "string",
	repo = "string",
	who = "string",
	note = "string",
	blurb = "string",
	arrange = "string",
	cover = "string",
	background = "string",
	header = "string",
	kind = "string",
	shape = "string",
	color = "string",
	snoozedUntil = "string",
}
local LINK_KINDS = { blocks = true, related = true }
-- The add operations, and the kind of node each one makes.
local ADD_TYPES: { [string]: string } = { addCard = "task", addNote = "task", addImage = "image", addGroup = "cluster" }
local OPERATIONS = {
	setFields = true,
	place = true,
	link = true,
	unlink = true,
	insert = true,
	group = true,
	ungroup = true,
	remove = true,
	removeGroup = true,
	move = true,
	tidy = true,
	chainClose = true,
	closeOut = true,
	addCard = true,
	addNote = true,
	addImage = true,
	addGroup = true,
	setData = true,
	resize = true,
	setStickers = true,
	setStickerLoadout = true,
}

local function requireString(object: json.Object, key: string): string
	local text = assert(getStringField(object[key]), `{key} must be a string`)
	return text
end

local function optionalString(object: json.Object, key: string): string?
	local value = object[key]

	if value == nil then
		return nil
	end

	local text = assert(getStringField(value), `{key} must be a string`)
	return text
end

local function requireNumber(object: json.Object, key: string): number
	local value = object[key]
	assert(type(value) == "number", `{key} must be a number`)
	return value :: number
end

local function optionalBoolean(object: json.Object, key: string): boolean?
	local value = object[key]

	if value == nil then
		return nil
	end

	assert(type(value) == "boolean", `{key} must be true or false`)
	return value :: boolean
end

local function optionalNumber(object: json.Object, key: string): number?
	local value = object[key]

	if value == nil then
		return nil
	end

	assert(type(value) == "number", `{key} must be a number`)
	return value :: number
end

local function requireObject(object: json.Object, key: string): json.Object
	return assert(json.asObject(object[key] :: json.Value), `{key} must be an object`)
end

local function requireArray(object: json.Object, key: string): json.Array
	return assert(json.asArray(object[key] :: json.Value), `{key} must be an array`)
end

local function requireStrings(object: json.Object, key: string): { string }
	local values = assert(json.asArray(object[key] :: json.Value), `{key} must be an array of ids`)
	assert(#values > 0, `{key} needs at least one id`)
	local result = {}

	for _, value in values do
		local id = assert(getStringField(value), `{key} must be an array of ids`)
		table.insert(result, id)
	end

	return result
end

local function parseFields(object: json.Object): { [string]: string | number }
	local fields = assert(json.asObject(object.fields :: json.Value), "fields must be an object")
	local result: { [string]: string | number } = {}

	for key, value in fields do
		-- Objects carry a marker key that isn't a field name.
		if type(key) ~= "string" then
			continue
		end

		-- A pull request number, resolved against the card's repository, or
		-- empty to take it off.
		if key == "pr" then
			assert(
				value == "" or (type(value) == "number" and value >= 1 and value == math.floor(value :: number)),
				"pr must be a pull request number, or empty"
			)
			result.pr = value :: string | number
			continue
		end

		local expected = FIELD_TYPES[key]
		assert(expected, `{key} is not a field an operation can set`)
		assert(type(value) == expected, `{key} must be a {expected}`)
		result[key] = value :: string | number
	end

	assert(next(result) ~= nil, "fields needs at least one field")
	return result
end

local function parseOperation(object: json.Object): Operation
	local op = object.op
	assert(type(op) == "string" and OPERATIONS[op :: string], `unknown operation: {tostring(op)}`)
	local operation: Operation = { op = op :: string }

	if operation.op == "setFields" then
		operation.id = requireString(object, "id")
		operation.fields = parseFields(object)
	elseif operation.op == "place" then
		operation.id = requireString(object, "id")
		operation.x = requireNumber(object, "x")
		operation.y = requireNumber(object, "y")
	elseif operation.op == "link" then
		operation.from = requireString(object, "from")
		operation.to = requireString(object, "to")
		operation.kind = optionalString(object, "kind") or "blocks"
		assert(LINK_KINDS[operation.kind :: string], "kind must be blocks or related")
		operation.label = optionalString(object, "label")
	elseif operation.op == "unlink" then
		operation.from = requireString(object, "from")
		operation.to = requireString(object, "to")
	elseif operation.op == "insert" then
		operation.id = requireString(object, "id")
		operation.from = requireString(object, "from")
		operation.to = requireString(object, "to")
	elseif operation.op == "group" then
		operation.label = requireString(object, "label")
		operation.items = requireStrings(object, "items")
		operation.id = optionalString(object, "id")
	elseif operation.op == "move" then
		operation.id = requireString(object, "id")
		operation.group = optionalString(object, "group")
	elseif operation.op == "remove" then
		operation.id = requireString(object, "id")
		operation.reconnect = optionalBoolean(object, "reconnect")
	elseif ADD_TYPES[operation.op] then
		operation.id = requireString(object, "id")
		operation.nodeType = ADD_TYPES[operation.op]
		operation.x = requireNumber(object, "x")
		operation.y = requireNumber(object, "y")
		operation.group = optionalString(object, "group")
		operation.width = optionalNumber(object, "width")
		operation.height = optionalNumber(object, "height")
		local data = requireObject(object, "data")
		operation.data = data

		-- A note and a work item are both task cards; the type tells them
		-- apart.
		if operation.op == "addNote" then
			assert(data.type == "note", "addNote needs data.type to be note")
		elseif operation.op == "addCard" then
			assert(data.type ~= "note", "addCard is for work items; use addNote for a note")
		end
	elseif operation.op == "setData" then
		operation.id = requireString(object, "id")
		operation.data = requireObject(object, "data")
	elseif operation.op == "resize" then
		operation.id = requireString(object, "id")
		operation.clear = optionalBoolean(object, "clear")

		if not operation.clear then
			operation.width = requireNumber(object, "width")
			operation.height = requireNumber(object, "height")
		end
	elseif operation.op == "setStickers" then
		operation.stickers = requireArray(object, "stickers")
	elseif operation.op == "setStickerLoadout" then
		operation.stickerLoadout = requireArray(object, "stickerLoadout")
	else
		-- ungroup, removeGroup, tidy, chainClose, and closeOut each take only
		-- the id of the item they act on.
		operation.id = requireString(object, "id")
	end

	return operation
end

-- Turns the operations in a request into typed edits. A bad one names its
-- position and what's wrong with it.
local function parseOperations(values: json.Array): { Operation }
	local operations: { Operation } = {}

	for index, value in values do
		local succeeded, result = pcall(function(): Operation
			return parseOperation(assert(json.asObject(value), "must be an object"))
		end)

		if not succeeded then
			error(`operation {index}: {getErrorText(result)}`, 0)
		end

		table.insert(operations, result)
	end

	return operations
end

return parseOperations
