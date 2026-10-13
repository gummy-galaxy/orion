local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local runSubcommand = require("@root/cli/runSubcommand")
local serve = require("@root/cli/mcp/serve")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { serve = serve }

return table.freeze({
	help = "Agent tools over MCP",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "serve" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
