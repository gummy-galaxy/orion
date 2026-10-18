local json = require("@std/json")

local adapterTypes = require("@root/adapters/types")
local findBranch = require("@root/adapters/findBranch")
local findRef = require("@root/refs/findRef")
local getClaudeDir = require("@root/adapters/claude/getClaudeDir")
local getUnix = require("@root/adapters/getUnix")
local listSessions = require("@root/adapters/claude/listSessions")
local types = require("@root/types")

type Record = adapterTypes.Record
type Context = adapterTypes.Context
type Doc = types.Doc
type Item = types.Item
type Source = types.Source
type CommandRunner = types.CommandRunner

local LOOKBACK_DAYS = 21
local STATE_LABEL = {
	working = "Working in Claude Code",
	waiting = "Waiting on you in Claude Code",
	done = "Finished its turn in Claude Code",
}

-- owner/name from a GitHub remote, over SSH or HTTPS.
local function parseRemote(remote: string): string?
	local repo = remote:match("[:/]([^/:]+/[^/]+)$")
	return if repo then repo:gsub("%.git$", "") else nil
end

-- The one card with this branch in any repository, for a session whose folder is gone.
local function findOnlyBranch(doc: Doc, branch: string): Item?
	local found: Item? = nil

	for _, item in doc.nodes do
		local branchRef = findRef(item, "branch")
		local pull = findRef(item, "pull")
		local details = if pull then pull.details else nil

		if
			item.type == "task"
			and ((branchRef and branchRef.key:match("@(.+)$") == branch) or (details and details.branch == branch))
		then
			if found then
				return nil
			end

			found = item
		end
	end

	return found
end

-- Claude Code sessions as `session` refs on the cards whose branch they ran on. It never adds cards: a session with
-- no card waits for triage.
local function collect(source: Source, run: CommandRunner, context: Context): { Record }
	local dir = getClaudeDir(source)
	local sessions = listSessions(dir, run, getUnix(context.now) - LOOKBACK_DAYS * 86400)
	local repos: { [string]: string } = {}
	local checked: { [string]: boolean } = {}
	local records: { Record } = {}

	local function getRepo(cwd: string): string?
		if not checked[cwd] then
			local result = run({ "git", "-C", cwd, "remote", "get-url", "origin" })
			checked[cwd] = true
			repos[cwd] = if result.ok then parseRemote((result.stdout:gsub("%s+$", ""))) else nil
		end

		return repos[cwd]
	end

	for _, session in sessions do
		local repo = getRepo(session.cwd)
		local stamp = os.date("!%Y-%m-%dT%H:%M:%SZ", session.updatedAt)

		table.insert(records, {
			ref = {
				source = source.id,
				kind = "session",
				key = `claude:{session.id}`,
				updatedAt = stamp,
				checkedAt = context.now,
				stateLabel = STATE_LABEL[session.state] :: string,
				sessionState = session.state,
				lastMessage = if session.lastMessage then session.lastMessage:sub(1, 280) else nil,
				details = json.object({
					agent = "claude",
					sessionId = session.id,
					title = session.title,
					cwd = session.cwd,
					branch = session.branch,
					isLive = session.isLive,
				}),
			},
			label = session.title,
			isUpdateOnly = true,
			isUncounted = true,
			setLabelOnUpdate = false,
			setRepoOnUpdate = false,
			findFallback = function(current: Doc): Item?
				return if repo
					then findBranch(current, repo, session.branch)
					else findOnlyBranch(current, session.branch)
			end,
		})
	end

	return records
end

return collect
