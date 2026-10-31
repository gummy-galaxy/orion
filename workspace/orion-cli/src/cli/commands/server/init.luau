local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local runSubcommand = require("@root/cli/runSubcommand")
local start = require("@root/cli/commands/server/start")
local status = require("@root/cli/commands/server/status")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { start = start, status = status }

return table.freeze({
	help = "The server the app and agents talk to",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "start", "status" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
