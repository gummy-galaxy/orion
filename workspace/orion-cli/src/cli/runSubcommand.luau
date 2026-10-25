local cli = require("@batteries/cli")

local context = require("@root/cli/context")

type Command = context.Command
type Context = context.Context

-- Runs the subcommand the parser selected, and says which ones there are when none was chosen.
local function runSubcommand(parser: cli.Parser, commands: { [string]: Command }, options: Context)
	local name, subcommand = parser:selected()

	if not (name and subcommand) then
		local choices = {}

		for _, command in parser.commands do
			table.insert(choices, command.name)
		end

		error(`choose {table.concat(choices, ", ")}`)
	end

	commands[name].run(subcommand, options)
end

return runSubcommand
