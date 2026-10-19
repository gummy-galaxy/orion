local cli = require("@batteries/cli")
local json = require("@std/json")

local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local getItem = require("@root/graph/getItem")
local getRequired = require("@root/cli/getRequired")
local getStringField = require("@root/getStringField")
local insertBetween = require("@root/graph/insertBetween")
local requestedRevision = require("@root/cli/requestedRevision")
local resolveId = require("@root/query/resolveId")
local runEdit = require("@root/cli/runEdit")

type Context = context.Context

return table.freeze({
	help = "Insert an item into an existing link, replacing it with two links of the same kind",
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("between", "option", { help = "Source item whose link is replaced (required)" })
		parser:add("target", "variadic", { help = "Target item whose link is replaced" })
		parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
		parser:add("if-revision", "option", { help = "Write only if the document has this revision" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local id, from = getRequired(parser, "id"), getRequired(parser, "between")
		local targets = parser:variadics()
		assert(#targets == 1, "insert needs exactly one target after --between <from>")
		local to = targets[1]
		local dryRun = parser:has("dry-run")

		local doc, baseRevision = runEdit(options.dir, dryRun, requestedRevision(parser), function(current)
			id, from, to = resolveId(current, id), resolveId(current, from), resolveId(current, to)
			insertBetween(current, id, from, to)
		end)

		if options.asJson then
			options.write(json.serialize(
				json.object({
					action = "insert",
					dryRun = dryRun,
					baseRevision = baseRevision,
					revision = doc.revision,
					items = { json.object({ id = id, label = getStringField(getItem(doc, id).data.label) }) },
					from = from,
					to = to,
				}),
				true
			))
		else
			local revision = if dryRun then `{baseRevision}` else `{baseRevision} → {doc.revision}`
			options.write(
				`{if dryRun then "Would insert" else "Inserted"} {id} between {from} and {to} at revision {revision}`
			)
		end
	end,
})
