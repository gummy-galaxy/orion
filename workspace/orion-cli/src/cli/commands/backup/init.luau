local cli = require("@batteries/cli")

local backups = require("@root/cli/commands/backup/backups")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local restore = require("@root/cli/commands/backup/restore")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { list = backups, restore = restore }

return table.freeze({
	help = "Saved revisions of a canvas",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "list", "restore" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
