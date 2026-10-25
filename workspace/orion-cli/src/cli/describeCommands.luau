local cli = require("@batteries/cli")

local cliTypes = require("@root/cli/types")
local definitions = require("@root/cli/definitions")

export type Argument = {
	name: string,
	kind: "positional" | "flag" | "option" | "variadic",
	help: string?,
	required: boolean,
	aliases: { string },
	type: cliTypes.ValueType,
	values: { string }?,
	minimum: number?,
	mcp: cliTypes.ArgumentMcp?,
}

export type CommandDescription = {
	name: string,
	help: string?,
	usage: string,
	arguments: { Argument },
	commands: { CommandDescription },
	-- The command's MCP tool, when it declares one.
	mcp: cliTypes.ToolDeclaration?,
}

-- Every command repeats these, so the reference lists them once instead.
local SHARED_ARGUMENTS = { help = true, canvas = true }

-- Walks a parser and the commands under it, in the order they were defined, skipping hidden entries.
local function describeCommands(parser: cli.Parser, name: string, help: string?): CommandDescription
	local arguments: { Argument } = {}
	local commands: { CommandDescription } = {}
	local details = definitions.arguments[parser] or {}

	for _, argument in parser.arguments do
		if argument.options.hidden or SHARED_ARGUMENTS[argument.name] then
			continue
		end

		local aliases: { string } = argument.options.aliases or {}
		local detail = details[argument.name]
		local description: Argument = {
			name = argument.name,
			kind = argument.kind,
			help = argument.options.help,
			required = argument.options.required == true,
			aliases = aliases,
			type = if detail
				then detail.type
				elseif argument.kind == "flag" then "boolean"
				elseif argument.kind == "variadic" then "list"
				else "text",
			values = if detail then detail.values else nil,
			minimum = if detail then detail.minimum else nil,
			mcp = if detail then detail.mcp else nil,
		}

		table.insert(arguments, description)
	end

	for _, command in parser.commands do
		if not command.options.hidden then
			table.insert(commands, describeCommands(command.parser, `{name} {command.name}`, command.options.help))
		end
	end

	return {
		name = name,
		help = help,
		usage = (parser:usage(name):gsub("^Usage: ", "")),
		arguments = arguments,
		commands = commands,
		mcp = definitions.tools[parser],
	}
end

return describeCommands
