local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local create = require("@root/cli/workspace/create")
local current = require("@root/cli/workspace/current")
local list = require("@root/cli/workspace/list")
local rename = require("@root/cli/workspace/rename")
local set = require("@root/cli/workspace/set")
local use = require("@root/cli/workspace/use")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	list = list,
	create = create,
	rename = rename,
	set = set,
	use = use,
	current = current,
}

return table.freeze({
	help = "List, create, rename, and choose workspaces",
	define = function(parser: cli.Parser)
		for _, name in { "list", "create", "rename", "set", "use", "current" } do
			local subcommand = parser:subcommand(name, { help = COMMANDS[name].help })
			subcommand:add("help", "flag", { help = "Show this help", aliases = { "h" } })
			subcommand:add("workspace", "option", { help = "Use this workspace for this command" })
			COMMANDS[name].define(subcommand)
		end
	end,

	run = function(parser: cli.Parser, options: Context)
		local name, subcommand = parser:selected()
		assert(name and subcommand, "choose list, create, rename, set, use, or current")
		COMMANDS[name].run(subcommand, options)
	end,
})
