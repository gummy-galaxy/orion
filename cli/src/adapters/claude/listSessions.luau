local fs = require("@std/fs")

local claudeTypes = require("@root/adapters/claude/types")
local parseTranscript = require("@root/adapters/claude/parseTranscript")
local readLiveSessions = require("@root/adapters/claude/readLiveSessions")
local readTail = require("@root/adapters/claude/readTail")
local types = require("@root/types")

type Session = claudeTypes.Session
type SessionState = claudeTypes.SessionState
type CommandRunner = types.CommandRunner

local TAIL_BYTES = 256 * 1024
local DEFAULT_BRANCHES = { main = true, master = true, HEAD = true }

-- Claude Code sessions changed since `since`, read without writing anything. Each transcript lives in
-- `projects/<folder>/<session id>.jsonl`; only the end of each is read.
local function listSessions(dir: string, run: CommandRunner, since: number): { Session }
	local projects = `{dir}/projects`
	local sessions: { Session } = {}

	if not fs.exists(projects) then
		return sessions
	end

	local live = readLiveSessions(dir, run)

	for _, project in fs.listDirectory(projects) do
		if project.type ~= "dir" then
			continue
		end

		local folder = `{projects}/{project.name}`

		for _, entry in fs.listDirectory(folder) do
			local id = entry.name:match("^([%w%-]+)%.jsonl$")

			if entry.type ~= "file" or not id then
				continue
			end

			local filePath = `{folder}/{entry.name}`
			local modified = fs.metadata(filePath).modified:toNanoseconds() / 1e9

			if modified < since then
				continue
			end

			local transcript = parseTranscript(readTail(filePath, TAIL_BYTES))
			local branch = transcript.branch

			if not branch or not transcript.cwd or DEFAULT_BRANCHES[branch] then
				continue
			end

			local process = live[id]
			local state: SessionState = transcript.state

			-- A busy process is mid-turn whatever the transcript last recorded. One that's idle, or gone, mid-turn
			-- stopped on something: a permission prompt, an interrupt, or a crash.
			if process and process.status == "busy" then
				state = "working"
			elseif (process and process.status ~= "idle") or state == "working" then
				state = "waiting"
			end

			table.insert(sessions, {
				id = id,
				path = filePath,
				cwd = transcript.cwd :: string,
				branch = branch,
				title = (if process then process.name else nil) or transcript.title or branch,
				state = state,
				isLive = process ~= nil,
				lastMessage = transcript.lastMessage,
				updatedAt = modified,
			})
		end
	end

	return sessions
end

return listSessions
