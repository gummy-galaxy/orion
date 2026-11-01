local cli = require("@batteries/cli")

local attachType = require("@root/cli/commands/card/attachType")
local chainClose = require("@root/cli/commands/card/chainClose")
local context = require("@root/cli/context")
local create = require("@root/cli/commands/card/create")
local defineSubcommands = require("@root/cli/defineSubcommands")
local detachType = require("@root/cli/commands/card/detachType")
local done = require("@root/cli/commands/card/done")
local import = require("@root/cli/commands/card/import")
local list = require("@root/cli/commands/card/list")
local listTypes = require("@root/cli/commands/card/listTypes")
local runSubcommand = require("@root/cli/runSubcommand")
local set = require("@root/cli/commands/card/set")
local snooze = require("@root/cli/commands/card/snooze")
local timeline = require("@root/cli/commands/card/timeline")
local typeShow = require("@root/cli/commands/card/typeShow")
local unsnooze = require("@root/cli/commands/card/unsnooze")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	list = list,
	create = create,
	set = set,
	timeline = timeline,
	done = done,
	["chain-close"] = chainClose,
	import = import,
	snooze = snooze,
	unsnooze = unsnooze,
	["attach-type"] = attachType,
	["detach-type"] = detachType,
	types = listTypes,
	["type-show"] = typeShow,
}

return table.freeze({
	help = "Work items on the canvas",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, {
			"list",
			"create",
			"set",
			"timeline",
			"done",
			"chain-close",
			"import",
			"snooze",
			"unsnooze",
			"attach-type",
			"detach-type",
			"types",
			"type-show",
		})
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
