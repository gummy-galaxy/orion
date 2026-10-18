local cli = require("@batteries/cli")

local add = require("@root/cli/placement/add")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/placement/list")
local remove = require("@root/cli/placement/remove")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	add = add,
	remove = remove,
	list = list,
}

return table.freeze({
	help = "Places a card appears on the canvas (spike for #122)",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "add", "remove", "list" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
