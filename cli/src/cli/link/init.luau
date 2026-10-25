local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local create = require("@root/cli/link/create")
local defineSubcommands = require("@root/cli/defineSubcommands")
local insert = require("@root/cli/link/insert")
local remove = require("@root/cli/link/remove")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	create = create,
	remove = remove,
	insert = insert,
}

return table.freeze({
	help = "Dependencies between items",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "create", "remove", "insert" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
