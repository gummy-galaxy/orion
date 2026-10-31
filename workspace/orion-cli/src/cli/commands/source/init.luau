local cli = require("@batteries/cli")

local add = require("@root/cli/commands/source/add")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/commands/source/list")
local matches = require("@root/cli/commands/source/matches")
local remove = require("@root/cli/commands/source/remove")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { list = list, add = add, remove = remove, matches = matches }

return table.freeze({
	help = "Sources that ingest imports work from",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "list", "add", "remove", "matches" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
