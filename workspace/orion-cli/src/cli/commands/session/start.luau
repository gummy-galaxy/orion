local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local addIdPositional = require("@root/cli/arguments/addIdPositional")
local context = require("@root/cli/context")
local getItem = require("@root/canvas/items/getItem")
local getRequired = require("@root/cli/arguments/getRequired")
local loadDoc = require("@root/storage/canvases/loadDoc")
local presets = require("@root/sources/sessions/presets")
local readSourceCommands = require("@root/sources/readSourceCommands")
local requireItem = require("@root/cli/edits/requireItem")
local resolveId = require("@root/canvas/query/resolveId")
local startSessionAsync = require("@root/sources/sessions/startSessionAsync")
local writeResult = require("@root/cli/output/writeResult")

type Context = context.Context

local PRESET_IDS: { string } = {}

for _, preset in presets do
	table.insert(PRESET_IDS, preset.id)
end

return table.freeze({
	help = "Open an agent session on a card's work, with a preset's prompt filled in to send",
	mcp = {
		description = "Open a new agent session on a card's work, such as Claude Code in Claude Desktop, with a preset's prompt filled in for the person to send. It starts where the card's branch is checked out, or else in the repository's clone with the prompt asking for a worktree. Nothing runs until they send it. orion session presets lists the presets that fit a card and where it would start.",
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
				place = start.place,
				folder = start.folder or json.null,
				url = start.url,
				opened = shouldOpen,
			}),
			if shouldOpen
				then `Opened {start.agent} to {start.preset.label:lower()}. Send the prompt there to start.`
				else start.url
		)
	end,
})
