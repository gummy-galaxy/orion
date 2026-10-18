local json = require("@std/json")

local describeCommands = require("@root/cli/describeCommands")

type CommandDescription = describeCommands.CommandDescription

-- Turns a command description into JSON, keeping empty argument and command lists as arrays.
local function serializeCommands(command: CommandDescription): json.Object
	local arguments: json.Array = {}
	local commands: json.Array = {}

	for _, argument in command.arguments do
		local aliases: json.Array = {}

		for _, alias in argument.aliases do
			table.insert(aliases, alias)
		end

		table.insert(
			arguments,
			json.object({
				name = argument.name,
				kind = argument.kind,
				help = argument.help,
				required = argument.required,
				aliases = aliases,
			})
		)
	end

	for _, child in command.commands do
		table.insert(commands, serializeCommands(child))
	end

	return json.object({
		name = command.name,
		help = command.help,
		usage = command.usage,
		arguments = arguments,
		commands = commands,
	})
end

return serializeCommands
