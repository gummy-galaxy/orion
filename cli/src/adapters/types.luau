local githubTypes = require("@root/github/types")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Ref = types.Ref
type Source = types.Source
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
export type RefreshOptions = { discover: boolean, now: string }
export type Adapter = {
	kind: string,
	createSource: ({ [string]: { string } }) -> Source,
	collect: (Source, CommandRunner, Context) -> { Record },
	refresh: ((Doc, CommandRunner, RefreshOptions) -> githubTypes.Report)?,
	collectOrder: number?,
}

return {}
