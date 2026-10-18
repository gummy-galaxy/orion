local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/ci/list")
local runSubcommand = require("@root/cli/runSubcommand")
local snooze = require("@root/cli/ci/snooze")
local unsnooze = require("@root/cli/ci/unsnooze")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { list = list, snooze = snooze, unsnooze = unsnooze }

return table.freeze({
	help = "CI jobs whose failures cards leave out",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "list", "snooze", "unsnooze" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
