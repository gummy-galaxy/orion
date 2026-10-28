local adapterTypes = require("@root/adapters/types")
local types = require("@root/types")

export type Entry = {
	input: string,
	resolved: types.ResolvedRef?,
	record: adapterTypes.Record?,
	error: string?,
}

-- status is "added", "existing", or "failed". Dry runs say "added" for cards
-- they would add.
export type Outcome = {
	input: string,
	status: string,
	id: string?,
	label: string?,
	error: string?,
}

-- status is "existing" when a card already tracks the ref, or "found" for a
-- card that hasn't been added yet.
export type CardLookup = {
	status: string,
	item: types.Item,
}

export type Report = {
	dryRun: boolean,
	baseRevision: number,
	revision: number,
	outcomes: { Outcome },
}

return nil
