local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local definitions = require("@root/cli/definitions")

type Command = context.Command

-- Adds each named subcommand with its own help, --canvas option, and MCP tool,
-- then lets the command define its options.
local function defineSubcommands(parser: cli.Parser, commands: { [string]: Command }, names: { string })
	for _, name in names do
		local subcommand = parser:subcommand(name, { help = commands[name].help })
		subcommand:add("help", "flag", { help = "Show this help", aliases = { "h" } })
		subcommand:add("canvas", "option", { help = "Use this canvas for this command" })
		definitions.tools[subcommand] = commands[name].mcp
		commands[name].define(subcommand)
	end
end

return defineSubcommands
