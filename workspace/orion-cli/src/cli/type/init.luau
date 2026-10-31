local cli = require("@batteries/cli")

local attach = require("@root/cli/type/attach")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local detach = require("@root/cli/type/detach")
local list = require("@root/cli/type/list")
local runSubcommand = require("@root/cli/runSubcommand")
local show = require("@root/cli/type/show")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { list = list, show = show, attach = attach, detach = detach }

return table.freeze({
	help = "Card types: what a card is, its fields, face, and states",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "list", "show", "attach", "detach" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
