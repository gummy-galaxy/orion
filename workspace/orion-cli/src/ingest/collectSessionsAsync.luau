local json = require("@std/json")

local adapterTypes = require("@root/adapters/types")
local findBranch = require("@root/adapters/findBranch")
local findRef = require("@root/refs/findRef")
local getUnix = require("@root/adapters/getUnix")
local types = require("@root/types")

type AgentVerbs = adapterTypes.AgentVerbs
type Record = adapterTypes.Record
type Context = adapterTypes.Context
type Session = adapterTypes.Session
type Doc = types.Doc
type Item = types.Item
type Source = types.Source
type CommandRunner = types.CommandRunner

local LOOKBACK_DAYS = 21

-- owner/name from a GitHub remote, over SSH or HTTPS.
local function parseRemote(remote: string): string?
	local repo = remote:match("[:/]([^/:]+/[^/]+)$")
	return if repo then (repo:gsub("%.git$", "")) else nil
end

-- The one card with this branch in any repository, for a session whose folder
-- has no remote, or is gone.
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

local function getStateLabel(session: Session, agent: AgentVerbs): string
	return if session.state == "working" then `Working in {agent.name}` else `Waiting on you in {agent.name}`
end

--[[
	An agent's sessions as `session` refs on the cards whose branch they ran
	on, read through its adapter's agent verbs. It never adds cards: a session
	with no card on its branch waits for triage. A session's repository comes
	from its adapter or, failing that, from its folder's `origin` remote. What
	a session said stays out of the ref, so the canvas's files never copy a
	transcript; `readTurnsAsync` reads it live.
]]
local function collectSessionsAsync(source: Source, agent: AgentVerbs, run: CommandRunner, context: Context): { Record }
	local sessions = agent.listSessionsAsync(source, run, getUnix(context.now) - LOOKBACK_DAYS * 86400)
	local repos: { [string]: string | false } = {}
	local records: { Record } = {}

	local function getRepoAsync(cwd: string): string?
		if repos[cwd] == nil then
			local result = run({ "git", "-C", cwd, "remote", "get-url", "origin" })
			repos[cwd] = if result.ok then parseRemote((result.stdout:gsub("%s+$", ""))) or false else false
		end

		return repos[cwd] or nil
	end

	for _, session in sessions do
		local branch = session.branch

		if not branch then
			continue
		end

		local repo = session.repo or getRepoAsync(session.cwd)
		local details = json.object({ cwd = session.cwd, branch = branch, isLive = session.isLive })

		for field, value in session.details or {} do
			details[field] = value
		end

		table.insert(records, {
			ref = {
				source = source.id,
				kind = "session",
				key = session.title or branch,
				id = `{source.kind}:{session.id}`,
				updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ", session.updatedAt) :: string,
				checkedAt = context.now,
				stateLabel = getStateLabel(session, agent),
				sessionState = session.state,
				details = details,
			},
			label = session.title or branch,
			isUpdateOnly = true,
			isUncounted = true,
			setLabelOnUpdate = false,
			setRepoOnUpdate = false,
			findFallback = function(current: Doc): Item?
				return if repo then findBranch(current, repo, branch) else findOnlyBranch(current, branch)
			end,
		})
	end

	return records
end

return collectSessionsAsync
