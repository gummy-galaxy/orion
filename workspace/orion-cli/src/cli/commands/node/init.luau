local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local find = require("@root/cli/commands/node/find")
local move = require("@root/cli/commands/node/move")
local query = require("@root/cli/commands/node/query")
local remove = require("@root/cli/commands/node/remove")
local runSubcommand = require("@root/cli/runSubcommand")
local show = require("@root/cli/commands/node/show")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	show = show,
	query = query,
	find = find,
	remove = remove,
	move = move,
}

return table.freeze({
	help = "Any item or group",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "show", "query", "find", "remove", "move" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
