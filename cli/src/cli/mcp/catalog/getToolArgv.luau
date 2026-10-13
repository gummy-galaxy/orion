local json = require("@std/json")

local appendFlag = require("@root/cli/mcp/catalog/appendFlag")
local appendOption = require("@root/cli/mcp/catalog/appendOption")
local findTool = require("@root/cli/mcp/catalog/findTool")
local getRequiredString = require("@root/cli/mcp/catalog/getRequiredString")
local isAbsent = require("@root/cli/mcp/catalog/isAbsent")
local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field
type Tool = mcpTypes.Tool

local function checkValue(field: Field, value: json.Value)
	local name = field.name

	if field.kind == "boolean" then
		assert(type(value) == "boolean", `{name} must be a boolean`)
	elseif field.kind == "int" then
		assert(
			type(value) == "number" and value >= 1 and value == math.floor(value),
			`{name} must be a positive integer`
		)
	elseif field.kind == "strings" then
		local list = json.asArray(value)
		assert(list, `{name} must be a list of strings`)

		for _, entry in list do
			assert(type(entry) == "string" and entry ~= "", `{name} must be a list of strings`)
		end
	elseif field.kind == "operations" then
		local steps = json.asArray(value)
		assert(steps and #steps > 0, `{name} must be a list of operations`)
	elseif field.kind == "enum" then
		local values = field.values or {}
		assert(
			type(value) == "string" and table.find(values, value),
			`{name} must be one of: {table.concat(values, ", ")}`
		)
	else
		assert(type(value) == "string", `{name} must be a string`)
		assert(#value >= (field.minLength or if field.kind == "id" then 1 else 0), `{name} must not be empty`)
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

-- Places each field where its command expects it: positionals first, then options and flags.
local function buildArgv(tool: Tool, arguments: json.Object): { string }
	local argv = table.clone(tool.command)

	for _, field in tool.fields do
		if field.at == "positional" then
			table.insert(argv, getRequiredString(arguments, field.name))
		end
	end

	for _, field in tool.fields do
		local value = arguments[field.name]

		if field.at == "option" then
			if isAbsent(value) then
				assert(not field.required, `missing {field.name}`)
			else
				appendOption(argv, field.flag or field.name, value)
			end
		elseif field.at == "flag" then
			appendFlag(argv, field.flag or field.name, value)
		elseif field.at == "csv" then
			local list = if isAbsent(value) then nil else json.asArray(value)
			assert(list and #list > 0, `missing {field.name}`)

			local ids: { string } = {}

			for _, id in list do
				assert(type(id) == "string" and id ~= "", `missing {field.name}`)
				table.insert(ids, id)
			end

			table.insert(argv, `--{field.flag or field.name}`)
			table.insert(argv, table.concat(ids, ","))
		end
	end

	if tool.json then
		table.insert(argv, "--json")
	end

	return argv
end

-- Turns a tool call into the CLI arguments for the command it delegates to.
local function getToolArgv(name: string, arguments: json.Object): { string }
	local tool = assert(findTool(name), `unknown tool: {name}`)
	checkArguments(tool, arguments)

	if tool.build then
		return tool.build(arguments)
	end

	return buildArgv(tool, arguments)
end

return getToolArgv
