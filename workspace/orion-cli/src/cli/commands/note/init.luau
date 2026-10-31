local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local create = require("@root/cli/commands/note/create")
local defineSubcommands = require("@root/cli/defineSubcommands")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	create = create,
}

return table.freeze({
	help = "Notes for context, decisions, and reminders",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "create" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
