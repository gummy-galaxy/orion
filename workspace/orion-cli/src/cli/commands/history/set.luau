local cli = require("@batteries/cli")
local fs = require("@std/fs")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local captureDoc = require("@root/canvas/operations/captureDoc")
local context = require("@root/cli/context")
local decodeDoc = require("@root/storage/files/decodeDoc")
local describeChanges = require("@root/canvas/operations/describeChanges")
local getBackups = require("@root/storage/backups/getBackups")
local getChanges = require("@root/canvas/operations/getChanges")
local getRequired = require("@root/cli/arguments/getRequired")
local operationTypes = require("@root/canvas/operations/types")
local requestedRevision = require("@root/cli/arguments/requestedRevision")
local runEdit = require("@root/cli/edits/runEdit")
local serializeChanges = require("@root/canvas/operations/serializeChanges")
local storeTypes = require("@root/storage/types")
local types = require("@root/types")

type Backup = storeTypes.Backup
type Changes = operationTypes.Changes
type Context = context.Context
type Doc = types.Doc

-- Gives the canvas the nodes, links, and settings of the newest backup that
-- holds `revision`.
local function setRevision(dir: string, doc: Doc, revision: number)
	assert(revision ~= doc.revision, `the canvas is already at revision {revision}`)
	local selected: Backup?

	for _, backup in getBackups(dir) do
		if backup.revision == revision then
			selected = backup
			break
		end
	end

	assert(selected, `no saved revision {revision}; orion history list shows the ones you can jump to`)
	local snapshot = decodeDoc(fs.readFileToString(selected.file))
	doc.nodes = snapshot.nodes
	doc.links = snapshot.links
	doc.settings = snapshot.settings
	doc.github = snapshot.github
	local raw = doc.raw or json.object({})
	raw.settings = if snapshot.raw then snapshot.raw.settings else nil
	doc.raw = raw
end

return table.freeze({
	help = "Jump the canvas to a saved revision, as a new revision, so later ones stay in the list",
	mcp = { annotations = { destructiveHint = true } },
	define = function(parser: cli.Parser)
		addArgument(parser, "revision", "positional", {
			help = "The revision to jump to, as orion history list shows it",
			type = "integer",
			minimum = 0,
		})
		parser:add("dry-run", "flag", { help = "Preview what would change without writing" })
		addArgument(parser, "if-revision", "option", {
			help = "Write only if the document has this revision",
			type = "integer",
			minimum = 0,
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local value = getRequired(parser, "revision")
		assert(value:match("^%d+$"), "revision must be a nonnegative integer")
		local target = tonumber(value) :: number
		local dryRun = parser:has("dry-run")
		local changes: Changes

		local doc, baseRevision = runEdit(options.dir, dryRun, requestedRevision(parser), function(current)
			local before = captureDoc(current)
			setRevision(options.dir, current, target)
			changes = getChanges(before, current)
		end)

		if options.asJson then
			options.write(json.serialize(
				json.object({
					action = "history set",
					dryRun = dryRun,
					baseRevision = baseRevision,
					revision = doc.revision,
					target = target,
					changes = serializeChanges(changes),
				}),
				true
			))
			return
		end

		local lines = {
			if dryRun
				then `Would set the canvas to revision {target} at revision {baseRevision}`
				else `Set the canvas to revision {target} as revision {doc.revision}`,
		}

		for _, line in describeChanges(changes) do
			table.insert(lines, line)
		end

		options.write(table.concat(lines, "\n"))
	end,
})
