local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local getItem = require("@root/graph/getItem")
local getRequired = require("@root/cli/getRequired")
local loadDoc = require("@root/store/loadDoc")
local presets = require("@root/sessions/presets")
local readSourceCommands = require("@root/sources/readSourceCommands")
local requireItem = require("@root/cli/requireItem")
local resolveId = require("@root/query/resolveId")
local startSessionAsync = require("@root/sessions/startSessionAsync")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

local PRESET_IDS: { string } = {}

for _, preset in presets do
	table.insert(PRESET_IDS, preset.id)
end

return table.freeze({
	help = "Open an agent session on a card's work, with a preset's prompt filled in to send",
	mcp = {
		description = "Open a new agent session, such as Claude Code in Claude Desktop, in the folder where a card's branch is checked out, with a preset's prompt filled in for the person to send. Nothing runs until they send it. orion session presets lists the presets that fit a card.",
		annotations = { openWorldHint = true },
	},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		addArgument(parser, "preset", "option", {
			help = `What the session works on: {table.concat(PRESET_IDS, " or ")} (default work)`,
			type = "enum",
			values = PRESET_IDS,
		})
		parser:add("dry-run", "flag", { help = "Print the link without opening it" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local id = resolveId(doc, getRequired(parser, "id"))
		requireItem(doc, id)

		local shouldOpen = not parser:has("dry-run")
		local start = startSessionAsync(
			doc,
			getItem(doc, id),
			parser:get("preset") or "work",
			options.runner,
			readSourceCommands(options.root, options.workspace),
			shouldOpen
		)

		writeResult(
			options,
			json.object({
				id = id,
				preset = start.preset.id,
				agent = start.agent,
				folder = start.folder,
				url = start.url,
				opened = shouldOpen,
			}),
			if shouldOpen
				then `Opened {start.agent} in {start.folder} to {start.preset.label:lower()}. Send the prompt to start.`
				else start.url
		)
	end,
})
