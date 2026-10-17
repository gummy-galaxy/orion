local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local move = require("@root/cli/node/move")
local query = require("@root/cli/node/query")
local remove = require("@root/cli/node/remove")
local runSubcommand = require("@root/cli/runSubcommand")
local show = require("@root/cli/node/show")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	show = show,
	query = query,
	remove = remove,
	move = move,
}

return table.freeze({
	help = "Any item or group",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "show", "query", "remove", "move" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
