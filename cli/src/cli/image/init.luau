local batteriesCli = require("@batteries/cli")

local add = require("@root/cli/image/add")
local context = require("@root/cli/context")
local list = require("@root/cli/image/list")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { add = add, list = list }

return table.freeze({
	help = "Add or list image nodes",
	define = function(parser: batteriesCli.Parser)
		for _, name in { "add", "list" } do
			local sub = parser:subcommand(name, { help = COMMANDS[name].help })
			sub:add("help", "flag", { help = "Show this help", aliases = { "h" } })
			sub:add("workspace", "option", { help = "Use this workspace for this command" })
			COMMANDS[name].define(sub)
		end
	end,
	run = function(parser: batteriesCli.Parser, options: Context)
		local name, sub = parser:selected()
		assert(name and sub, "choose image add or list")
		COMMANDS[name].run(sub, options)
	end,
})
