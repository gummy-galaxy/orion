local batteriesCli = require("@batteries/cli")

local add = require("@root/cli/source/add")
local context = require("@root/cli/context")
local list = require("@root/cli/source/list")
local remove = require("@root/cli/source/remove")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { list = list, add = add, remove = remove }

return table.freeze({
	help = "List, add, or remove ingestion sources",
	define = function(parser: batteriesCli.Parser)
		for _, name in { "list", "add", "remove" } do
			local sub = parser:subcommand(name, { help = COMMANDS[name].help })
			sub:add("help", "flag", { help = "Show this help", aliases = { "h" } })
			sub:add("workspace", "option", { help = "Use this workspace for this command" })
			COMMANDS[name].define(sub)
		end
	end,

	run = function(parser: batteriesCli.Parser, options: Context)
		local name, sub = parser:selected()
		assert(name and sub, "choose list, add, or remove")
		COMMANDS[name].run(sub, options)
	end,
})
