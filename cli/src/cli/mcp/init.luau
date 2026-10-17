local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local runSubcommand = require("@root/cli/runSubcommand")
local start = require("@root/cli/mcp/start")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { start = start }

return table.freeze({
	help = "Agent tools over MCP",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "start" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
