local cli = require("@batteries/cli")

local add = require("@root/cli/link/add")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local insert = require("@root/cli/link/insert")
local remove = require("@root/cli/link/remove")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	add = add,
	remove = remove,
	insert = insert,
}

return table.freeze({
	help = "Dependencies between items",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "add", "remove", "insert" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
