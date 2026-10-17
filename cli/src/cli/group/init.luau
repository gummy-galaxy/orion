local cli = require("@batteries/cli")

local add = require("@root/cli/group/add")
local context = require("@root/cli/context")
local create = require("@root/cli/group/create")
local defineSubcommands = require("@root/cli/defineSubcommands")
local list = require("@root/cli/group/list")
local remove = require("@root/cli/group/remove")
local runSubcommand = require("@root/cli/runSubcommand")
local set = require("@root/cli/group/set")
local tidy = require("@root/cli/group/tidy")
local ungroup = require("@root/cli/group/ungroup")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	list = list,
	create = create,
	add = add,
	remove = remove,
	set = set,
	ungroup = ungroup,
	tidy = tidy,
}

return table.freeze({
	help = "Groups of items",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "list", "create", "add", "remove", "set", "ungroup", "tidy" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
