local json = require("@std/json")

local findTool = require("@root/cli/mcp/catalog/findTool")
local isAbsent = require("@root/cli/mcp/catalog/isAbsent")
local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field
type Tool = mcpTypes.Tool

local function isList(field: Field): boolean
	return field.type == "list" or field.type == "commaList"
end

local function checkValue(field: Field, value: json.Value)
	local name = field.name

	if field.type == "boolean" then
		assert(type(value) == "boolean", `{name} must be a boolean`)
	elseif field.type == "integer" then
		local minimum = field.minimum or 1
		assert(
			type(value) == "number" and value >= minimum and value == math.floor(value),
			if minimum == 0 then `{name} must be a nonnegative integer` else `{name} must be a positive integer`
		)
	elseif isList(field) then
		local list = json.asArray(value)
		assert(list, `{name} must be a list of strings`)

		for _, entry in list do
			assert(type(entry) == "string" and entry ~= "", `{name} must be a list of strings`)
		end
	elseif field.type == "jsonList" then
		local list = json.asArray(value)
		assert(list and #list > 0, `{name} must be a list of objects`)

		for _, entry in list do
			assert(json.asObject(entry), `{name} must be a list of objects`)
		end
	elseif field.type == "enum" then
		local values = field.values or {}
		assert(
			type(value) == "string" and table.find(values, value),
			`{name} must be one of: {table.concat(values, ", ")}`
		)
	else
		assert(type(value) == "string", `{name} must be a string`)
		assert(value ~= "" or not (field.required or field.type == "id"), `{name} must not be empty`)
	end
end

local function checkArguments(tool: Tool, arguments: json.Object)
	local fields: { [string]: Field } = {}

	for _, field in tool.fields do
		fields[field.name] = field
	end

	for key, value in arguments do
		if type(key) ~= "string" then
			continue
		end

		local field = fields[key]
		assert(field, `unknown argument: {key}`)

		if not isAbsent(value) then
			checkValue(field, value)
		end
	end
end

-- The text an option carries: lists joined with commas, and JSON lists serialized.
local function getOptionText(field: Field, value: json.Value): string
	if field.type == "commaList" then
		return table.concat(json.asArray(value) :: json.Array, ",")
	elseif field.type == "jsonList" then
		return json.serialize(value)
	end

	return tostring(value)
end

-- An empty list counts as no value, as leaving the argument out would.
local function hasValue(field: Field, value: json.Value): boolean
	if isAbsent(value) then
		return false
	end

	local list = if isList(field) then json.asArray(value) else nil
	return list == nil or #list > 0
end

-- Places each field where its command expects it: positionals and variadics first, then options and flags.
local function buildArgv(tool: Tool, arguments: json.Object): { string }
	local argv = table.clone(tool.command)

	for _, field in tool.fields do
		local value = arguments[field.name]

		if field.at ~= "positional" and field.at ~= "variadic" then
			continue
		elseif not hasValue(field, value) then
			assert(not field.required, `missing {field.name}`)
		elseif isList(field) then
			for _, entry in json.asArray(value) :: json.Array do
				table.insert(argv, tostring(entry))
			end
		else
			table.insert(argv, tostring(value))
		end
	end

	for _, field in tool.fields do
		local value = arguments[field.name]

		if field.at == "option" then
			if hasValue(field, value) then
				table.insert(argv, `--{field.argument}`)
				table.insert(argv, getOptionText(field, value))
			else
				assert(not field.required, `missing {field.name}`)
			end
		elseif field.at == "flag" and value == true then
			table.insert(argv, `--{field.argument}`)
		end
	end

	if tool.json then
		table.insert(argv, "--json")
	end

	return argv
end

-- Moves arguments given under an old name to the field that replaced it.
local function renameArguments(tool: Tool, arguments: json.Object): json.Object
	local renamed = json.object({})

	for key, value in arguments do
		local field = if type(key) == "string" then tool.renamedArguments[key] else nil

		if field then
			assert(arguments[field] == nil, `{key} is now {field}, so give only {field}`)
			renamed[field] = value
		else
			renamed[key] = value
		end
	end

	return renamed
end

-- Turns a tool call into the CLI arguments for the command it runs.
local function getToolArgv(tools: { Tool }, name: string, arguments: json.Object): { string }
	local tool = assert(findTool(tools, name), `unknown tool: {name}`)
	local current = renameArguments(tool, arguments)
	checkArguments(tool, current)
	return buildArgv(tool, current)
end

return getToolArgv
