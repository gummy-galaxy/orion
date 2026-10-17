local cli = require("@batteries/cli")

local add = require("@root/cli/card/add")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local done = require("@root/cli/card/done")
local import = require("@root/cli/card/import")
local list = require("@root/cli/card/list")
local runSubcommand = require("@root/cli/runSubcommand")
local set = require("@root/cli/card/set")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	list = list,
	add = add,
	set = set,
	done = done,
	import = import,
}

return table.freeze({
	help = "Work items on the canvas",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "list", "add", "set", "done", "import" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
