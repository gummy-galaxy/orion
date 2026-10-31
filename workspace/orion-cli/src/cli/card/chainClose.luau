local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local addIdPositional = require("@root/cli/addIdPositional")
local closeChain = require("@root/graph/closeChain")
local context = require("@root/cli/context")
local getItem = require("@root/graph/getItem")
local getLabel = require("@root/graph/getLabel")
local getRequired = require("@root/cli/getRequired")
local graphTypes = require("@root/graph/types")
local requestedRevision = require("@root/cli/requestedRevision")
local requireItem = require("@root/cli/requireItem")
local resolveId = require("@root/query/resolveId")
local runEdit = require("@root/cli/runEdit")
local types = require("@root/types")

type ChainStep = graphTypes.ChainStep
type ClosedChain = graphTypes.ClosedChain
type Context = context.Context
type Doc = types.Doc

local function describeSteps(doc: Doc, steps: { ChainStep }): json.Array
	local entries: json.Array = {}

	for _, step in steps do
		table.insert(entries, json.object({ id = step.id, label = getLabel(getItem(doc, step.id)), hops = step.hops }))
	end

	return entries
end

return table.freeze({
	help = "Close out a done card and the waiting done cards chained to it, so their Done stamps show",
	mcp = {
		description = "Close out a done card and every waiting done card chained to it through finished cards, the "
			.. "same as double-clicking a shimmering card in the app. "
			.. "Closing out a chain is the person's reward for finishing it, so don't close out on your own: "
			.. "finishing a card with orion_card_done leaves it waiting for them. "
			.. "Close out only when the person asks.",
	},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("dry-run", "flag", { help = "Preview the chain and current revision without writing" })
		addArgument(parser, "if-revision", "option", {
			help = "Write only if the document has this revision",
			type = "integer",
			minimum = 0,
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local id = getRequired(parser, "id")
		local dryRun = parser:has("dry-run")
		local result: ClosedChain

		local doc, baseRevision = runEdit(options.dir, dryRun, requestedRevision(parser), function(current)
			id = resolveId(current, id)
			requireItem(current, id)
			result = closeChain(current, id)
		end)

		if options.asJson then
			options.write(json.serialize(
				json.object({
					action = "chain-close",
					dryRun = dryRun,
					baseRevision = baseRevision,
					revision = doc.revision,
					closed = describeSteps(doc, result.closed),
					passed = describeSteps(doc, result.passed),
				}),
				true
			))
			return
		end

		local revision = if dryRun then `{baseRevision}` else `{baseRevision} → {doc.revision}`
		local count = #result.closed
		local lines = {
			`{if dryRun then "Would close out" else "Closed out"} {count} {if count == 1 then "card" else "cards"} `
				.. `at revision {revision}`,
		}

		for _, step in result.closed do
			table.insert(lines, `  {step.id} · {getLabel(getItem(doc, step.id))}`)
		end

		options.write(table.concat(lines, "\n"))
	end,
})
