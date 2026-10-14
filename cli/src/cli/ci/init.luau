local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local snooze = require("@root/cli/ci/snooze")
local store = require("@root/store")
local unsnooze = require("@root/cli/ci/unsnooze")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { snooze = snooze, unsnooze = unsnooze }

return table.freeze({
	help = "List, snooze, or unsnooze CI jobs whose failures cards leave out",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })

		for _, name in { "snooze", "unsnooze" } do
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

		local snoozes = store.load(options.dir).settings.checkSnoozes

		if options.asJson then
			local values: json.Array = {}

			for _, entry in snoozes do
				local value = json.object({ repo = entry.repo, name = entry.name, at = entry.at })
				value["until"] = entry.untilTime
				value.passed = table.clone(entry.passed) :: json.Array
				table.insert(values, value)
			end

			options.write(json.serialize(values, true))
			return
		end

		local lines: { string } = {}

		for _, entry in snoozes do
			local ending = if entry.untilTime then `until {entry.untilTime}` else "until it passes"
			local passed = if #entry.passed > 0 then `, passed on {#entry.passed} cards` else ""
			table.insert(lines, `{entry.repo}  {entry.name}  {ending}{passed}`)
		end

		options.write(if #lines > 0 then table.concat(lines, "\n") else "No snoozed CI jobs.")
	end,
})
