local githubTypes = require("@root/github/types")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Ref = types.Ref
type Source = types.Source
type ResolvedRef = types.ResolvedRef
type CommandRunner = types.CommandRunner

export type Record = {
	ref: Ref,
	label: string,
	repo: string?,
	itemKind: string?,
	status: string?,
	who: string?,
	isUpdateOnly: boolean?,
	isUncounted: boolean?,
	createStatus: string?,
	createWho: string?,
	findFallback: ((Doc) -> Item?)?,
	shouldFindFallbackFirst: boolean?,
	-- Sets the item's status and whose move it is from the source, once the
	-- record is placed.
	updateStatus: ((Item) -> ())?,
	mentionText: string?,
	setRepoOnUpdate: boolean?,
	setLabelOnUpdate: boolean?,
	keepPullKind: boolean?,
}

-- `commands` holds the programs this machine runs for the canvas's sources, by
-- source id, from `readSourceCommands`.
export type Context = { now: string, since: string, doc: Doc, commands: { [string]: { string } } }
-- Records found by lookupRefs, keyed by getRefKey. Refs missing from both maps
-- were not found.
export type LookupResult = { records: { [string]: Record }, failures: { [string]: string } }
export type RefreshOptions = { now: string }
export type Adapter = {
	kind: string,
	-- Returns the source and, for a kind that runs a program, the command this
	-- machine runs for it.
	createSource: ({ [string]: { string } }) -> (Source, { string }?),
	collect: (Source, CommandRunner, Context) -> { Record },
	-- Fetches against a snapshot of the workspace and returns the step that
	-- applies the results, so callers can fetch outside the workspace lock and
	-- take it only to apply.
	refresh: ((Doc, CommandRunner, RefreshOptions) -> (Doc) -> githubTypes.Report)?,
	-- Like `refresh`, limited to what changed since the last poll, with no
	-- apply step when nothing did.
	refreshChanged: ((
		Doc,
		CommandRunner,
		githubTypes.PollState,
		githubTypes.Want,
		now: string
	) -> githubTypes.ChangedRefresh)?,
	collectOrder: number?,
	-- Recognizes a pasted URL for this kind; sources are the configured ones,
	-- of any kind.
	refFromUrl: ((string, { Source }) -> ResolvedRef?)?,
	-- Builds a ref from a source:key reference addressed to one configured
	-- source of this kind.
	refFromKey: ((string, Source) -> ResolvedRef?)?,
	-- Looks up records for resolved refs of this kind, in as few calls as the
	-- adapter allows. Failures carry a reason.
	lookupRefs: ((refs: { ResolvedRef }, context: Context, run: CommandRunner) -> LookupResult)?,
}

return {}
