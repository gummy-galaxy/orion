local aliasEntries = require("@root/aliases/entries")
local aliasTypes = require("@root/aliases/types")
local describeCommands = require("@root/cli/describeCommands")
local mcpTypes = require("@root/cli/mcp/types")

type Alias = aliasTypes.Alias
type Argument = describeCommands.Argument
type CommandDescription = describeCommands.CommandDescription
type Field = mcpTypes.Field
type Tool = mcpTypes.Tool

-- Every command takes --canvas, so describeCommands leaves it out and each tool gets this field unless it omits it.
local CANVAS_FIELD: Field = table.freeze({
	name = "canvas",
	argument = "canvas",
	at = "option",
	type = "canvas",
	required = false,
	description = "Canvas name. Omit to use the canvas selected in Orion.",
}) :: Field

local function toCamelCase(name: string): string
	return (name:gsub("%-(%w)", string.upper))
end

-- Positionals and words are required unless an argument says otherwise, since commands fail without them.
local function isRequired(argument: Argument): boolean
	if argument.required then
		return true
	elseif argument.mcp and argument.mcp.required ~= nil then
		return argument.mcp.required
	end

	return argument.kind == "positional" or argument.type == "words"
end

local function getField(argument: Argument): Field
	return {
		name = toCamelCase(argument.name),
		argument = argument.name,
		at = argument.kind,
		type = argument.type,
		required = isRequired(argument),
		description = if argument.mcp and argument.mcp.description then argument.mcp.description else argument.help,
		values = argument.values,
		minimum = argument.minimum,
	}
end

-- The old tool names that still reach a command: one for each command alias whose new path starts its path.
local function getToolAliases(words: { string }, aliases: { Alias }): { string }
	local names: { string } = {}

	for _, alias in aliases do
		local to = string.split(alias.to, " ")

		if alias.kind ~= "command" or #to > #words then
			continue
		end

		local startsPath = true

		for position, word in to do
			startsPath = startsPath and words[position] == word
		end

		if startsPath then
			local old = string.split(alias.from, " ")
			table.move(words, #to + 1, #words, #old + 1, old)
			table.insert(names, `orion_{table.concat(old, "_")}`)
		end
	end

	return names
end

-- The old argument names a command's tool still takes, after its options were renamed.
local function getRenamedArguments(path: string, aliases: { Alias }): { [string]: string }
	local renamed: { [string]: string } = {}

	for _, alias in aliases do
		if alias.kind == "option" and alias.command == path then
			renamed[toCamelCase(alias.from)] = toCamelCase(alias.to)
		end
	end

	return renamed
end

local function buildTool(command: CommandDescription, path: string, aliases: { Alias }, problems: { string }): Tool?
	local declaration = command.mcp

	if declaration == nil then
		table.insert(problems, `orion {path} declares no MCP tool, or why it has none`)
		return nil
	end

	local omit: { [string]: boolean } = {}

	for _, omission in declaration.omit or {} do
		omit[omission.option] = true
	end

	-- Positionals and variadics come first, then the canvas, then options and flags, as on the command line.
	local names: { [string]: boolean } = { canvas = true }
	local fields: { Field } = {}
	local options: { Field } = {}
	local takesJson = false

	for _, argument in command.arguments do
		names[argument.name] = true

		if argument.name == "json" then
			takesJson = true
		elseif omit[argument.name] then
			continue
		elseif argument.kind == "positional" or argument.kind == "variadic" then
			table.insert(fields, getField(argument))
		else
			table.insert(options, getField(argument))
		end
	end

	for name in omit do
		if not names[name] then
			table.insert(problems, `orion {path} omits --{name}, which it doesn't take`)
		end
	end

	if not omit.canvas then
		table.insert(fields, CANVAS_FIELD)
	end

	table.move(options, 1, #options, #fields + 1, fields)

	local words = string.split(path, " ")

	return {
		name = `orion_{table.concat(words, "_")}`,
		description = declaration.description or command.help or "",
		command = words,
		fields = fields,
		json = takesJson,
		annotations = declaration.annotations,
		aliases = getToolAliases(words, aliases),
		renamedArguments = getRenamedArguments(path, aliases),
	}
end

local function collectTools(command: CommandDescription, aliases: { Alias }, tools: { Tool }, problems: { string })
	local path = (command.name:gsub("^orion ?", ""))

	if command.mcp and command.mcp.skip then
		return
	elseif #command.commands == 0 then
		local tool = buildTool(command, path, aliases, problems)

		if tool then
			table.insert(tools, tool)
		end

		return
	end

	for _, child in command.commands do
		collectTools(child, aliases, tools, problems)
	end
end

-- Builds a tool for every command in the table that doesn't skip MCP, in the order orion help lists them. Fails
-- when a command declares no tool or omits an option it doesn't take, so MCP can't fall behind the CLI. Each tool
-- keeps the old names that aliases give it, which default to the shipped entries.
local function buildTools(root: CommandDescription, aliases: { Alias }?): { Tool }
	local tools: { Tool } = {}
	local problems: { string } = {}

	for _, command in root.commands do
		collectTools(command, aliases or aliasEntries, tools, problems)
	end

	assert(#problems == 0, table.concat(problems, "\n"))
	return tools
end

return buildTools
