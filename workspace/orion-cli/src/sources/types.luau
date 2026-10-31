local githubTypes = require("@root/sources/github/types")
local json = require("@std/json")
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
-- Records found by `lookupRefsAsync`, keyed by getRefKey. Refs missing from
-- both maps were not found.
export type LookupResult = { records: { [string]: Record }, failures: { [string]: string } }
export type RefreshOptions = { now: string }

-- The verbs of an adapter that brings work in from a service, such as GitHub
-- pull requests or Jira issues, as cards and refs.
export type SourceVerbs = {
	collectAsync: (Source, CommandRunner, Context) -> { Record },
	-- Fetches against a snapshot of the workspace and returns the step that
	-- applies the results, so callers can fetch outside the workspace lock and
	-- take it only to apply.
	refreshAsync: ((Doc, CommandRunner, RefreshOptions) -> (Doc) -> githubTypes.Report)?,
	-- Like `refreshAsync`, limited to what changed since the last poll, with no
	-- apply step when nothing did.
	refreshChangedAsync: ((
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
	lookupRefsAsync: ((refs: { ResolvedRef }, context: Context, run: CommandRunner) -> LookupResult)?,
}

-- working: the agent is running a turn. waiting: it's your move, because the
-- agent finished its turn or stopped on something only you can answer, such
-- as a permission prompt or an interrupt.
export type SessionState = "working" | "waiting"

-- One message in a session, with the agent's tool calls and results left out.
export type Turn = { role: "you" | "agent", text: string, at: string? }

-- An agent session as its adapter reports it, in terms every agent shares.
export type Session = {
	-- The agent's own id for the session, unique within the agent.
	id: string,
	-- The folder the session ran in.
	cwd: string,
	-- The branch checked out in `cwd`, which ties the session to a card.
	branch: string?,
	-- The repository as owner/name, when the adapter knows it without asking
	-- git.
	repo: string?,
	title: string?,
	state: SessionState,
	-- Whether the agent's process is still running, or nil when the adapter
	-- can't tell.
	isLive: boolean?,
	-- The last thing the agent said.
	lastMessage: string?,
	-- When the session last changed, in Unix seconds.
	updatedAt: number,
	-- What the agent recorded, in its own terms. Only its adapter reads it.
	details: json.Object?,
}

export type ResumeRequest = { sessionId: string, message: string }
export type StartRequest = { cwd: string, prompt: string }

-- The verbs of an adapter that finds an agent tool's sessions, such as Claude
-- Code's, and talks to them. Each one reads the agent's own records, so Orion
-- keeps no copy of a transcript.
export type AgentVerbs = {
	-- The agent's name as people know it, such as "Claude Code".
	name: string,
	-- Sessions that changed since `since`, in Unix seconds, read without
	-- writing anything. `cache` is a table the caller keeps between calls, for
	-- the adapter to remember what it read and skip what hasn't changed. A
	-- call may get an empty one.
	listSessionsAsync: (Source, CommandRunner, since: number, cache: { [string]: any }) -> { Session },
	-- Folders whose changes mean a session may have changed, such as when an
	-- agent's process records that it's busy or idle. `orion server start`
	-- watches them and lists sessions again when one does.
	watchPaths: ((Source) -> { string })?,
	-- A session's last `limit` turns, oldest first, or nil when the agent has
	-- no session with that id.
	readTurnsAsync: (Source, CommandRunner, sessionId: string, limit: number) -> { Turn }?,
	-- Sends a message to a session without opening it, calls `onTurn` with
	-- each turn of the reply as it arrives, and returns the session as the
	-- reply left it. Nothing calls this yet.
	resumeAsync: ((Source, ResumeRequest, onTurn: (Turn) -> ()) -> Session)?,
	-- Starts a session in a folder with a prompt, calls `onTurn` as
	-- `resumeAsync` does, and returns the new session. Nothing calls this yet.
	startAsync: ((Source, StartRequest, onTurn: (Turn) -> ()) -> Session)?,
}

-- One kind of source. An adapter has source verbs, agent verbs, or both, and
-- Orion calls only the ones it has.
export type Adapter = {
	kind: string,
	-- Returns the source and, for a kind that runs a program, the command this
	-- machine runs for it.
	createSource: ({ [string]: { string } }) -> (Source, { string }?),
	source: SourceVerbs?,
	agent: AgentVerbs?,
}

return nil
