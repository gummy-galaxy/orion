local addCard = require("@root/sources/import/addCard")
local findExisting = require("@root/sources/import/findExisting")
local getGroup = require("@root/canvas/groups/getGroup")
local getLabel = require("@root/canvas/items/getLabel")
local getSince = require("@root/sources/import/getSince")
local importTypes = require("@root/sources/import/types")
local loadDoc = require("@root/storage/canvases/loadDoc")
local lookupRecordsAsync = require("@root/sources/import/lookupRecordsAsync")
local resolveId = require("@root/canvas/query/resolveId")
local resolveInputs = require("@root/sources/import/resolveInputs")
local runEdit = require("@root/cli/edits/runEdit")
local types = require("@root/types")

type Doc = types.Doc
type CommandRunner = types.CommandRunner
type Entry = importTypes.Entry
type Outcome = importTypes.Outcome
type Report = importTypes.Report

export type Options = {
	dir: string,
	groupId: string?,
	dryRun: boolean,
	ifRevision: number?,
	now: string,
	runner: CommandRunner,
	-- The programs this machine runs for the canvas's sources, by source id.
	commands: { [string]: { string } },
}

-- Imports every ref in one transaction. Refs that don't resolve or can't be
-- looked up fail alone; refs already on the canvas are skipped and keep their
-- card. The lookups run before the write, so the transaction stays short.
local function importRefsAsync(inputs: { string }, options: Options): Report
	local doc = loadDoc(options.dir)
	local groupId = if options.groupId then resolveId(doc, options.groupId) else nil

	if groupId then
		getGroup(doc, groupId)
	end

	local entries = resolveInputs(inputs, doc.settings.sources)
	local pending: { Entry } = {}

	-- Cards that already exist need no lookup; the write re-checks them against
	-- the document it saves.
	for _, entry in entries do
		if entry.resolved and not findExisting(doc, entry.resolved.ref) then
			table.insert(pending, entry)
		end
	end

	lookupRecordsAsync(
		pending,
		{ now = options.now, since = getSince(options.now), doc = doc, commands = options.commands },
		options.runner
	)

	local adding = 0
	for _, entry in pending do
		if entry.record then
			adding += 1
		end
	end

	local outcomes: { Outcome } = {}

	local function place(current: Doc)
		table.clear(outcomes)

		for _, entry in entries do
			local outcome: Outcome = { input = entry.input, status = "failed", error = entry.error }

			if entry.error then
				table.insert(outcomes, outcome)
				continue
			end

			local ref = (entry.resolved :: types.ResolvedRef).ref
			local existing = findExisting(current, ref)

			if existing then
				outcome.status = "existing"
				outcome.id, outcome.label = existing.id, getLabel(existing)
			elseif entry.record then
				local item = addCard(current, entry.record, groupId)
				outcome.status = "added"
				outcome.id, outcome.label = item.id, getLabel(item)
			else
				outcome.error = "not found"
			end

			table.insert(outcomes, outcome)
		end
	end

	-- Nothing to add still checks --if-revision, but skips the write so the
	-- revision doesn't move.
	local written, baseRevision = runEdit(options.dir, options.dryRun or adding == 0, options.ifRevision, place)

	return {
		dryRun = options.dryRun,
		baseRevision = baseRevision,
		revision = written.revision,
		outcomes = outcomes,
	}
end

return importRefsAsync
