local aliasEntries = require("@root/cli/aliases/entries")
local aliasTypes = require("@root/cli/aliases/types")
local describeCommands = require("@root/cli/describeCommands")
local mcpTypes = require("@root/cli/mcp/types")

type Alias = aliasTypes.Alias
type Argument = describeCommands.Argument
type CommandDescription = describeCommands.CommandDescription
type Field = mcpTypes.Field
type Tool = mcpTypes.Tool

-- Every command takes --canvas, so describeCommands leaves it out of each
-- command's own arguments. Tools add it back with this field instead, unless a
-- command's MCP declaration omits it.
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

-- A command fails without its positionals or its free text, such as a card's
-- label, so their fields are required by default. An argument can still mark
-- itself required, or set `mcp.required` to change the default.
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

-- A renamed command keeps working under its old name for a release, through a
-- command alias. MCP clients may still call the old tool name too. This lists
-- those old names for one command: one for each alias that renamed the command
-- or one of its parents. If `card` was once called `task`, the tool for
-- `card list` also answers to `orion_task_list`.
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

-- Option aliases do the same for renamed options. This maps each old argument
-- name for one command's tool to the field it now fills.
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

	-- Positionals and variadics come first, then the canvas, then options and
	-- flags, as on the command line.
	local names: { [string]: boolean } = { canvas = true }
	local fields: { Field } = {}
	local options: { Field } = {}
	local takesJson = false

	for _, argument in command.arguments do
		names[argument.name] = true

		-- A tool call mustn't choose a program for Orion to run, so options
		-- that name one stay in the CLI.
		if argument.type == "command" and not omit[argument.name] then
			table.insert(
				problems,
				`orion {path} takes --{argument.name}, which runs a program, so its tool must omit it`
			)
		end

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

-- MCP clients call Orion through tools, one for each command that runs on its
-- own, such as `card list`. Groups like `card` get none. This builds the tools
-- from the command descriptions, in the order `orion help` lists the commands.
-- A command can opt out with `mcp.skip` and a reason.
--
-- Every other command has to declare its tool, and may omit options the tool
-- shouldn't take. Building fails when a command declares nothing, or omits an
-- option it doesn't have, so a new command or a renamed option can't quietly
-- leave MCP behind the CLI.
--
-- Specs can pass their own aliases. Otherwise the tools pick up the aliases
-- Orion ships with.
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
