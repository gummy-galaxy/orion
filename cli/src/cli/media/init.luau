local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local insert = require("@root/cli/media/insert")
local list = require("@root/cli/media/list")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { insert = insert, list = list }

return table.freeze({
	help = "Insert or list media nodes",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "insert", "list" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
