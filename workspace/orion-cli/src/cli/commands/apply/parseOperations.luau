local getErrorText = require("@root/common/errors/getErrorText")
local isAbsent = require("@root/cli/mcp/catalog/isAbsent")
local json = require("@std/json")
local types = require("@root/cli/commands/apply/types")

type Operation = types.Operation

-- Card fields an addCard step may set. Groups take their own, set with
-- setFields.
local CARD_FIELDS: { [string]: string } = {
	status = "string",
	repo = "string",
	who = "string",
	note = "string",
	kind = "string",
}

-- Fields setFields may change, with the type each one takes. Matches the fields
-- the CLI's set commands take.
local SET_FIELDS: { [string]: string } = {
	label = "string",
	status = "string",
	repo = "string",
	who = "string",
	note = "string",
	blurb = "string",
	arrange = "string",
	cover = "string",
	background = "string",
	kind = "string",
}

local LINK_KINDS = { blocks = true, related = true }

-- The keys each step reads. A key outside this list is refused, so a misspelled
-- field can't be silently ignored.
local STEP_KEYS: { [string]: { [string]: boolean } } = {
	addCard = {
		handle = true,
		label = true,
		group = true,
		after = true,
		before = true,
		ref = true,
		status = true,
		repo = true,
		who = true,
		note = true,
		kind = true,
	},
	addNote = { handle = true, text = true, group = true, after = true, before = true },
	group = { handle = true, label = true, items = true },
	setFields = { id = true, fields = true },
	link = { from = true, to = true, kind = true, label = true },
	unlink = { from = true, to = true },
	insert = { id = true, from = true, to = true },
	move = { id = true, group = true },
	remove = { id = true, reconnect = true },
	removeGroup = { id = true },
	ungroup = { id = true },
	tidy = { id = true },
	attachRef = { id = true, ref = true },
	detachRef = { id = true, ref = true },
}

local function optionalString(object: json.Object, key: string): string?
	local value = object[key]

	if isAbsent(value) then
		return nil
	end

	assert(type(value) == "string" and value ~= "", `{key} must be a nonempty string`)
	return value :: string
end

-- A string that may be empty, such as a link label, where empty clears it.
local function optionalText(object: json.Object, key: string): string?
	local value = object[key]

	if isAbsent(value) then
		return nil
	end

	assert(type(value) == "string", `{key} must be a string`)
	return value :: string
end

local function requireString(object: json.Object, key: string): string
	return (assert(optionalString(object, key), `{key} is required`))
end

local function optionalHandle(object: json.Object): string?
	local handle = optionalString(object, "handle")
	assert(handle == nil or handle:match("^[%w_%-]+$"), "handle may use letters, digits, - and _")
	return handle
end

local function optionalBoolean(object: json.Object, key: string): boolean?
	local value = object[key]

	if isAbsent(value) then
		return nil
	end

	assert(type(value) == "boolean", `{key} must be true or false`)
	return value :: boolean
end

local function requireItems(object: json.Object): { string }
	local values = json.asArray(object.items)
	assert(values and #values > 0, "items needs a list of at least one id")
	local ids: { string } = {}

	for _, value in values do
		assert(type(value) == "string" and value ~= "", "items must be a list of ids")
		table.insert(ids, value :: string)
	end

	return ids
end

-- Reads each field in `allowed` that the object sets, checking its type.
local function readFields(object: json.Object, allowed: { [string]: string }): { [string]: string | number }
	local fields: { [string]: string | number } = {}

	for key, expected in allowed do
		local value = object[key]

		if not isAbsent(value) then
			assert(type(value) == expected, `{key} must be a {expected}`)
			fields[key] = value :: string | number
		end
	end

	return fields
end

-- setFields takes its changes as one object, checked the same way.
local function readChanges(object: json.Object): { [string]: string | number }
	local changes = json.asObject(object.fields :: json.Value)
	assert(changes, "fields must be an object of field changes")
	local fields: { [string]: string | number } = {}

	for key, value in changes do
		if type(key) ~= "string" then
			continue
		end

		local expected = SET_FIELDS[key]
		assert(expected, `{key} is not a field setFields can change`)
		assert(type(value) == expected, `{key} must be a {expected}`)
		fields[key] = value :: string | number
	end

	assert(next(fields) ~= nil, "fields needs at least one field")
	return fields
end

local function parseStep(object: json.Object): Operation
	local op = object.op
	assert(type(op) == "string" and STEP_KEYS[op :: string], `unknown operation: {tostring(op)}`)
	local name = op :: string

	for key in object do
		-- Objects carry a marker key that isn't a field name.
		if type(key) == "string" then
			assert(key == "op" or STEP_KEYS[name][key], `{key} is not a field of {name}`)
		end
	end

	local operation: Operation = { op = name }

	if name == "addCard" then
		operation.handle = optionalHandle(object)
		operation.label = requireString(object, "label")
		operation.group = optionalString(object, "group")
		operation.after = optionalString(object, "after")
		operation.before = optionalString(object, "before")
		operation.ref = optionalString(object, "ref")
		operation.fields = readFields(object, CARD_FIELDS)
	elseif name == "addNote" then
		operation.handle = optionalHandle(object)
		operation.text = requireString(object, "text")
		operation.group = optionalString(object, "group")
		operation.after = optionalString(object, "after")
		operation.before = optionalString(object, "before")
	elseif name == "group" then
		operation.handle = optionalHandle(object)
		operation.label = requireString(object, "label")
		operation.items = requireItems(object)
	elseif name == "setFields" then
		operation.id = requireString(object, "id")
		operation.fields = readChanges(object)
	elseif name == "link" then
		operation.from = requireString(object, "from")
		operation.to = requireString(object, "to")
		operation.kind = optionalString(object, "kind") or "blocks"
		assert(LINK_KINDS[operation.kind :: string], "kind must be blocks or related")
		operation.label = optionalText(object, "label")
	elseif name == "unlink" then
		operation.from = requireString(object, "from")
		operation.to = requireString(object, "to")
	elseif name == "insert" then
		operation.id = requireString(object, "id")
		operation.from = requireString(object, "from")
		operation.to = requireString(object, "to")
	elseif name == "move" then
		operation.id = requireString(object, "id")
		-- A move has to say where it goes. Null sends the item to the top
		-- level, so a missing group can't do it by accident.
		assert(object.group ~= nil, "move needs group, or null for the top level")
		operation.group = optionalString(object, "group")
	elseif name == "attachRef" or name == "detachRef" then
		operation.id = requireString(object, "id")
		operation.ref = requireString(object, "ref")
	elseif name == "remove" then
		operation.id = requireString(object, "id")
		operation.reconnect = optionalBoolean(object, "reconnect")
	else
		-- removeGroup, ungroup, and tidy each take only the id of the item they
		-- act on.
		operation.id = requireString(object, "id")
	end

	return operation
end

-- Turns the steps of a plan into typed operations, or refuses the plan, naming
-- the first step that is wrong.
local function parseOperations(values: json.Array): { Operation }
	local operations: { Operation } = {}

	for index, value in values do
		local succeeded, result = pcall(function(): Operation
			return parseStep(assert(json.asObject(value), "must be an object"))
		end)

		if not succeeded then
			error(`operation {index}: {getErrorText(result)}`, 0)
		end

		table.insert(operations, result)
	end

	return operations
end

return parseOperations
