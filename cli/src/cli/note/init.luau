local cli = require("@batteries/cli")

local add = require("@root/cli/note/add")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	add = add,
}

return table.freeze({
	help = "Notes for context, decisions, and reminders",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "add" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
