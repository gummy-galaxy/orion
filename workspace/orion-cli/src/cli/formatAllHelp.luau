local describeCommands = require("@root/cli/describeCommands")
local getArgumentLabel = require("@root/cli/getArgumentLabel")

type Argument = describeCommands.Argument
type CommandDescription = describeCommands.CommandDescription

-- Notes that follow a command's arguments, keyed by its full name, such as the query grammar under orion node query.
export type Details = { [string]: string }

local function getAliasedLabel(argument: Argument): string
	local label = getArgumentLabel(argument)

	if #argument.aliases == 0 then
		return label
	end

	local aliases: { string } = {}

	for _, alias in argument.aliases do
		table.insert(aliases, if #alias == 1 then `-{alias}` else `--{alias}`)
	end

	return `{label} ({table.concat(aliases, ", ")})`
end

-- The command as it's typed: its name and positionals, since its options are listed beneath it.
local function getSynopsis(command: CommandDescription): string
	local words = { command.name }

	for _, argument in command.arguments do
		if argument.kind == "positional" or argument.kind == "variadic" then
			table.insert(words, getArgumentLabel(argument))
		end
	end

	return table.concat(words, " ")
end

local function formatArguments(arguments: { Argument }, lines: { string })
	local labels: { string } = {}
	local width = 0

	for index, argument in arguments do
		labels[index] = getAliasedLabel(argument)
		width = math.max(width, #labels[index])
	end

	for index, argument in arguments do
		local required = if argument.required then " (required)" else ""
		local padding = string.rep(" ", width - #labels[index])
		table.insert(lines, `    {labels[index]}{padding}  {argument.help or ""}{required}`)
	end
end

-- A command that runs on its own gets a block; one that only holds subcommands is left to them.
local function formatCommand(command: CommandDescription, isNoun: boolean, details: Details, lines: { string })
	if #command.arguments > 0 or #command.commands == 0 then
		table.insert(lines, "")
		table.insert(lines, `  {getSynopsis(command)}`)

		if command.help and not isNoun then
			table.insert(lines, `    {command.help}`)
		end

		formatArguments(command.arguments, lines)

		local detail = details[command.name]

		if detail then
			for line in detail:gmatch("[^\n]+") do
				table.insert(lines, `    {line}`)
			end
		end
	end

	for _, child in command.commands do
		formatCommand(child, false, details, lines)
	end
end

-- Lists every command under the root, grouped by its top-level noun, with each command's arguments and help.
local function formatAllHelp(root: CommandDescription, details: Details?): string
	local lines: { string } = {}
	local resolved = details or {}

	for index, noun in root.commands do
		if index > 1 then
			table.insert(lines, "")
		end

		table.insert(lines, `{noun.name:match("%S+$")}: {noun.help or ""}`)
		formatCommand(noun, true, resolved, lines)
	end

	return table.concat(lines, "\n")
end

return formatAllHelp
