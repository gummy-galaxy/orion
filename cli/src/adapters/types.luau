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
	getStatus: ((string, string?) -> (string, string?))?,
	mentionText: string?,
	setRepoOnUpdate: boolean?,
	setLabelOnUpdate: boolean?,
	keepPullKind: boolean?,
}

export type Context = { now: string, since: string, doc: Doc }
-- Records found by lookupRefs, keyed by getRefKey. Refs missing from both maps were not found.
export type LookupResult = { records: { [string]: Record }, failures: { [string]: string } }
export type RefreshOptions = { discover: boolean, now: string }
export type Adapter = {
	kind: string,
	createSource: ({ [string]: { string } }) -> Source,
	collect: (Source, CommandRunner, Context) -> { Record },
	refresh: ((Doc, CommandRunner, RefreshOptions) -> githubTypes.Report)?,
	collectOrder: number?,
	-- Recognizes a pasted URL for this kind; sources are the configured ones, of any kind.
	refFromUrl: ((string, { Source }) -> ResolvedRef?)?,
	-- Builds a ref from a source:key reference addressed to one configured source of this kind.
	refFromKey: ((string, Source) -> ResolvedRef?)?,
	-- Looks up records for resolved refs of this kind, in as few calls as the adapter allows. Failures carry a reason.
	lookupRefs: ((refs: { ResolvedRef }, context: Context, run: CommandRunner) -> LookupResult)?,
}

return {}
