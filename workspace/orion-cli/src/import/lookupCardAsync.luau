local addCard = require("@root/import/addCard")
local findExisting = require("@root/import/findExisting")
local getSince = require("@root/import/getSince")
local importTypes = require("@root/import/types")
local lookupRecordsAsync = require("@root/import/lookupRecordsAsync")
local resolveInputs = require("@root/import/resolveInputs")
local types = require("@root/types")

type CardLookup = importTypes.CardLookup
type CommandRunner = types.CommandRunner
type Doc = types.Doc

-- Finds the card a URL or source:key would import, without saving it: the card
-- already tracking it, or a new card shaped the way `orion card import` shapes
-- one. The document is left unchanged. Raises the reason when the input can't
-- be resolved or found. `commands` holds the programs this machine runs for the
-- canvas's sources, by source id.
local function lookupCardAsync(
	input: string,
	doc: Doc,
	commands: { [string]: { string } },
	now: string,
	runner: CommandRunner
): CardLookup
	local entry = resolveInputs({ input }, doc.settings.sources)[1]
	if entry.error then
		error(entry.error, 0)
	end

	local existing = findExisting(doc, (entry.resolved :: types.ResolvedRef).ref)
	if existing then
		return { status = "existing", item = existing }
	end

	lookupRecordsAsync({ entry }, { now = now, since = getSince(now), doc = doc, commands = commands }, runner)
	if not entry.record then
		error(entry.error or "not found", 0)
	end

	local scratch = table.clone(doc)
	scratch.nodes = table.clone(doc.nodes)

	return { status = "found", item = addCard(scratch, entry.record, nil) }
end

return lookupCardAsync
