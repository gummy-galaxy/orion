local json = require("@std/json")

local getCommandJson = require("@root/adapters/getCommandJson")
local hopTypes = require("@root/adapters/hop/types")
local types = require("@root/types")

type Worktree = hopTypes.Worktree
type Session = hopTypes.Session
type CommandRunner = types.CommandRunner

local function getString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

-- Runs `hop` from the PATH unless this machine set another hop executable for
-- the source.
local function parseData(run: CommandRunner, command: { string }?): ({ Worktree }, { Session })
	local binary = if command then command[1] else "hop"
	local list = json.asObject(getCommandJson(run, { binary, "list", "--json" }))
	assert(list, "hop list returned invalid JSON")
	local worktrees: { Worktree } = {}

	for _, raw in json.asArray(list.worktrees) or {} do
		local tree = json.asObject(raw)
		local repository = if tree then json.asObject(tree.repository) else nil
		local repo: string? = nil

		if repository then
			repo = getString(repository.remote) or getString(repository.name)
		end

		local branch = if tree then getString(tree.branch) else nil

		if tree and repo and branch then
			table.insert(worktrees, {
				repo = repo :: string,
				branch = branch,
				lastActivity = if type(tree.lastActivity) == "number" then tree.lastActivity else 0,
				onDefault = tree.onDefaultBranch == true,
			})
		end
	end

	local recent = json.asArray(getCommandJson(run, { binary, "recent", "--json", "--limit", "50" }))
	assert(recent, "hop recent returned invalid JSON")
	local sessions: { Session } = {}

	for _, raw in recent do
		local session = json.asObject(raw)
		local repo = if session then getString(session.repository) else nil
		local branch = if session then getString(session.branch) else nil
		local title = if session then getString(session.title) else nil

		if session and repo and branch and title then
			table.insert(sessions, {
				repo = repo,
				branch = branch,
				title = title:sub(1, 120),
				updatedAt = if type(session.updatedAt) == "number" then session.updatedAt else 0,
			})
		end
	end

	return worktrees, sessions
end

return parseData
