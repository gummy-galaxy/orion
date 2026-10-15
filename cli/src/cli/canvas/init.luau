local cli = require("@batteries/cli")

local archive = require("@root/cli/canvas/archive")
local check = require("@root/cli/check")
local context = require("@root/cli/context")
local create = require("@root/cli/canvas/create")
local current = require("@root/cli/canvas/current")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/canvas/list")
local path = require("@root/cli/canvas/path")
local rename = require("@root/cli/canvas/rename")
local restore = require("@root/cli/canvas/restore")
local runSubcommand = require("@root/cli/runSubcommand")
local set = require("@root/cli/canvas/set")
local use = require("@root/cli/canvas/use")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	list = list,
	create = create,
	rename = rename,
	set = set,
	archive = archive,
	restore = restore,
	use = use,
	current = current,
	path = path,
	check = check,
}

return table.freeze({
	help = "Canvases and their layout",
	define = function(parser: cli.Parser)
		defineSubcommands(
			parser,
			COMMANDS,
			{ "list", "create", "rename", "set", "archive", "restore", "use", "current", "path", "check" }
		)
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
