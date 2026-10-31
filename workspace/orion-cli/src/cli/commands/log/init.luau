local cli = require("@batteries/cli")

local add = require("@root/cli/commands/log/add")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/commands/log/list")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { add = add, list = list }

return table.freeze({
	help = "Add to the canvas log, and list it",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "add", "list" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
