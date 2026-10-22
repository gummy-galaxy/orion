local cli = require("@batteries/cli")

local add = require("@root/cli/card/add")
local chainClose = require("@root/cli/card/chainClose")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local done = require("@root/cli/card/done")
local import = require("@root/cli/card/import")
local list = require("@root/cli/card/list")
local runSubcommand = require("@root/cli/runSubcommand")
local set = require("@root/cli/card/set")
local snooze = require("@root/cli/card/snooze")
local timeline = require("@root/cli/card/timeline")
local unsnooze = require("@root/cli/card/unsnooze")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	list = list,
	add = add,
	set = set,
	timeline = timeline,
	done = done,
	["chain-close"] = chainClose,
	import = import,
	snooze = snooze,
	unsnooze = unsnooze,
}

return table.freeze({
	help = "Work items on the canvas",
	define = function(parser: cli.Parser)
		defineSubcommands(
			parser,
			COMMANDS,
			{ "list", "add", "set", "timeline", "done", "chain-close", "import", "snooze", "unsnooze" }
		)
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
