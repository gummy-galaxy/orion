local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local insert = require("@root/cli/media/insert")
local list = require("@root/cli/media/list")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { insert = insert, list = list }

return table.freeze({
	help = "Insert or list media nodes",
	define = function(parser: cli.Parser)
		for _, name in { "insert", "list" } do
			local sub = parser:subcommand(name, { help = COMMANDS[name].help })
			sub:add("help", "flag", { help = "Show this help", aliases = { "h" } })
			sub:add("workspace", "option", { help = "Use this workspace for this command" })
			COMMANDS[name].define(sub)
		end
	end,
	run = function(parser: cli.Parser, options: Context)
		local name, sub = parser:selected()
		assert(name and sub, "choose media insert or list")
		COMMANDS[name].run(sub, options)
	end,
})
