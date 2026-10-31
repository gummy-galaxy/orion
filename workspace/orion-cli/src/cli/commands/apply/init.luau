local cli = require("@batteries/cli")
local fs = require("@std/fs")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local applyOperations = require("@root/cli/commands/apply/applyOperations")
local context = require("@root/cli/context")
local parseOperations = require("@root/cli/commands/apply/parseOperations")
local requestedRevision = require("@root/cli/arguments/requestedRevision")
local runEdit = require("@root/cli/edits/runEdit")

type Context = context.Context

-- The plan comes from a file, from stdin with -, or inline with --plan, which
-- is how MCP calls pass it.
local function readPlan(parser: cli.Parser): string
	local file = parser:get("file")
	local plan = parser:get("plan")
	assert(not (file and plan), "use a plan file or --plan, not both")

	if plan then
		return plan
	end

	assert(file, "give a plan file, - to read stdin, or --plan <json>")
	return if file == "-" then fs.readFileToString("/dev/stdin") else fs.readFileToString(file)
end

local function getText(
	count: number,
	dryRun: boolean,
	baseRevision: number,
	revision: number,
	handles: { [string]: string }
): string
	local noun = if count == 1 then "operation" else "operations"
	local revisionText = if dryRun then `{baseRevision}` else `{baseRevision} → {revision}`
	local lines = { `{if dryRun then "Would apply" else "Applied"} {count} {noun} at revision {revisionText}` }
	local names: { string } = {}

	for handle in handles do
		table.insert(names, handle)
	end

	table.sort(names)

	for _, handle in names do
		table.insert(lines, `  @{handle} → {handles[handle]}`)
	end

	return table.concat(lines, "\n")
end

return table.freeze({
	help = "Apply a plan of cards, notes, groups, and links in one step",
	mcp = {
		description = "Apply a plan of cards, notes, groups, and links in one call. "
			.. "The plan is a list of operations that run in order, and it lands whole or not at all. "
			.. "addCard and addNote create items, and group wraps items; "
			.. 'each may declare a handle, and later operations refer to it as "@handle". '
			.. "Existing cards and groups are named by id. Other operations: "
			.. "setFields, link, unlink, insert, move, ungroup, tidy, remove, removeGroup. "
			.. "Use dryRun to preview the plan and the ids each handle gets.",
		annotations = { destructiveHint = true },
		omit = {
			{
				option = "file",
				reason = "reads the plan from a file or stdin, which a tool call can't pass; "
					.. "the tool takes it inline as plan",
			},
		},
	},
	define = function(parser: cli.Parser)
		parser:add("file", "positional", { help = "Plan file: a JSON list of operations, or - to read stdin" })
		addArgument(parser, "plan", "option", {
			help = "The plan as inline JSON, instead of a file",
			type = "jsonList",
			mcp = {
				required = true,
				description = "Operations in order. Each has an op field, such as addCard with label, or link with "
					.. "from and to. New cards and notes are placed after the last operation, beside the items "
					.. "they link to. Move needs group, or null for the top level.",
			},
		})
		parser:add("dry-run", "flag", { help = "Preview the plan without writing" })
		addArgument(parser, "if-revision", "option", {
			help = "Write only if the document has this revision",
			type = "integer",
			minimum = 0,
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local values = json.asArray(json.deserialize(readPlan(parser)) :: json.Value)
		assert(values, "a plan is a JSON list of operations")
		assert(#values > 0, "a plan needs at least one operation")
		local operations = parseOperations(values)
		local dryRun = parser:has("dry-run")
		local handles: { [string]: string } = {}

		local doc, baseRevision = runEdit(options.dir, dryRun, requestedRevision(parser), function(current)
			handles = applyOperations(current, operations)
		end)

		if options.asJson then
			local ids: json.Object = {}

			for handle, id in handles do
				ids[handle] = id
			end

			options.write(json.serialize(
				json.object({
					action = "apply",
					dryRun = dryRun,
					baseRevision = baseRevision,
					revision = doc.revision,
					operations = #operations,
					ids = ids,
				}),
				true
			))
		else
			options.write(getText(#operations, dryRun, baseRevision, doc.revision, handles))
		end
	end,
})
