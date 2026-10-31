local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local loadDoc = require("@root/storage/canvases/loadDoc")

type Context = context.Context

return table.freeze({
	help = "List the CI jobs snoozed on the canvas",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local snoozes = loadDoc(options.dir).settings.checkSnoozes

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
