local cli = require("@batteries/cli")

export type Argument = {
	name: string,
	kind: "positional" | "flag" | "option" | "variadic",
	help: string?,
	required: boolean,
	aliases: { string },
}

export type CommandDescription = {
	name: string,
	help: string?,
	usage: string,
	arguments: { Argument },
	commands: { CommandDescription },
}

-- Every command repeats these, so the reference lists them once instead.
local SHARED_ARGUMENTS = { help = true, canvas = true }

-- Walks a parser and the commands under it, in the order they were defined, skipping hidden entries.
local function describeCommands(parser: cli.Parser, name: string, help: string?): CommandDescription
	local arguments: { Argument } = {}
	local commands: { CommandDescription } = {}

	for _, argument in parser.arguments do
		if argument.options.hidden or SHARED_ARGUMENTS[argument.name] then
			continue
		end

		local aliases: { string } = argument.options.aliases or {}
		local description: Argument = {
			name = argument.name,
			kind = argument.kind,
			help = argument.options.help,
			required = argument.options.required == true,
			aliases = aliases,
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
	}
end

return describeCommands
