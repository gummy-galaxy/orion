local cli = require("@batteries/cli")
local json = require("@std/json")

local apply = require("@root/cli/suggestions/apply")
local context = require("@root/cli/context")
local dismiss = require("@root/cli/suggestions/dismiss")
local store = require("@root/store")
local suggest = require("@root/suggest")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { apply = apply, dismiss = dismiss }

return table.freeze({
	help = "List, apply, or dismiss group suggestions",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })

		for _, name in { "apply", "dismiss" } do
			local subcommand = parser:subcommand(name, { help = COMMANDS[name].help })
			subcommand:add("help", "flag", { help = "Show this help", aliases = { "h" } })
			subcommand:add("workspace", "option", { help = "Use this workspace for this command" })
			COMMANDS[name].define(subcommand)
		end
	end,

	run = function(parser: cli.Parser, options: Context)
		local name, subcommand = parser:selected()

		if name and subcommand then
			COMMANDS[name].run(subcommand, options)
			return
		end

		local result = suggest.getStored(store.load(options.dir))

		if options.asJson then
			options.write(json.serialize(suggest.convertToJson(result), true))
		else
			local lines: { string } = {}

			for _, group in result.groups do
				table.insert(
					lines,
					`{group.id}  {group.title}  [{table.concat(group.members, ", ")}] — {group.reason}`
				)
			end

			options.write(if #lines > 0 then table.concat(lines, "\n") else "No group suggestions.")
		end
	end,
})
