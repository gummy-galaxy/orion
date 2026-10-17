local cli = require("@batteries/cli")

local context = require("@root/cli/context")

type Command = context.Command

-- Adds each named subcommand with its own help and --canvas option, then lets the command define its options.
local function defineSubcommands(parser: cli.Parser, commands: { [string]: Command }, names: { string })
	for _, name in names do
		local subcommand = parser:subcommand(name, { help = commands[name].help })
		subcommand:add("help", "flag", { help = "Show this help", aliases = { "h" } })
		subcommand:add("canvas", "option", { help = "Use this canvas for this command" })
		commands[name].define(subcommand)
	end
end

return defineSubcommands
