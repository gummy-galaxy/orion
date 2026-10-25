local cli = require("@batteries/cli")

local add = require("@root/cli/theme/add")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/theme/list")
local remove = require("@root/cli/theme/remove")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { add = add, list = list, remove = remove }

return table.freeze({
	help = "Add, list, or remove theme files",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "add", "list", "remove" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
