local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/history/list")
local runSubcommand = require("@root/cli/runSubcommand")
local set = require("@root/cli/history/set")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { list = list, set = set }

return table.freeze({
	help = "A canvas's revisions, and jumping between them",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "list", "set" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
