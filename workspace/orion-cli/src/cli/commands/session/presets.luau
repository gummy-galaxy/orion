local cli = require("@batteries/cli")

local addIdPositional = require("@root/cli/arguments/addIdPositional")
local context = require("@root/cli/context")
local describeStart = require("@root/sources/sessions/describeStart")
local describeStartOptions = require("@root/sources/sessions/describeStartOptions")
local getItem = require("@root/canvas/items/getItem")
local getRequired = require("@root/cli/arguments/getRequired")
local getStartOptionsAsync = require("@root/sources/sessions/getStartOptionsAsync")
local loadDoc = require("@root/storage/canvases/loadDoc")
local readSourceCommands = require("@root/sources/readSourceCommands")
local requireItem = require("@root/cli/edits/requireItem")
local resolveId = require("@root/canvas/query/resolveId")
local writeResult = require("@root/cli/output/writeResult")

type Context = context.Context

return table.freeze({
	help = "List the presets a card can start an agent session with, and where it would start",
	mcp = {
		description = "List the presets that fit a card for orion session start, the agent that would run, "
			.. "and the folder it would start in, or what's in the way.",
		annotations = { readOnlyHint = true },
	},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local id = resolveId(doc, getRequired(parser, "id"))
		requireItem(doc, id)

		local startOptions = getStartOptionsAsync(
			doc,
			getItem(doc, id),
			options.runner,
			readSourceCommands(options.root, options.workspace)
		)
		local lines: { string } = {}

		for _, preset in startOptions.presets do
			table.insert(lines, `{preset.id}: {preset.label}`)
		end

		table.insert(lines, startOptions.problem or describeStart(startOptions))

		local described = describeStartOptions(startOptions)
		described.id = id

		writeResult(options, described, table.concat(lines, "\n"))
	end,
})
