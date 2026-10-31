local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local remove = require("@root/cli/commands/ref/remove")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	remove = remove,
}

return table.freeze({
	help = "Outside work attached to cards",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "remove" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
