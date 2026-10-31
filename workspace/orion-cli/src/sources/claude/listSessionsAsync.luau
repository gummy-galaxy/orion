local fs = require("@std/fs")

local adapterTypes = require("@root/sources/types")
local claudeTypes = require("@root/sources/claude/types")
local getClaudeDir = require("@root/sources/claude/getClaudeDir")
local parseTranscript = require("@root/sources/claude/parseTranscript")
local readLiveSessions = require("@root/sources/claude/readLiveSessions")
local readTail = require("@root/sources/claude/readTail")
local types = require("@root/types")

type Session = adapterTypes.Session
type SessionState = adapterTypes.SessionState
type Source = types.Source
type CommandRunner = types.CommandRunner
type Transcript = claudeTypes.Transcript
-- A transcript as last read, with the size and modification time it had.
type Read = { size: number, modified: number, transcript: Transcript }

local TAIL_BYTES = 256 * 1024
local DEFAULT_BRANCHES = { main = true, master = true, HEAD = true }

--[[
	Claude Code sessions changed since `since`, read without writing anything.
	Each transcript lives in `projects/<folder>/<session id>.jsonl`, and only
	the end of each is read, and only when its size or modification time moved
	since `cache` last saw it. Sessions on a default branch are left out, since
	no one card owns them.
]]
local function listSessionsAsync(
	source: Source,
	run: CommandRunner,
	since: number,
	cache: { [string]: any }
): { Session }
	local dir = getClaudeDir(source)
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
			local metadata = fs.metadata(filePath)
			local modified = metadata.modified:toNanoseconds() / 1e9

			if modified < since then
				continue
			end

			local read: Read? = cache[filePath]

			if not read or read.size ~= metadata.size or read.modified ~= modified then
				read = {
					size = metadata.size,
					modified = modified,
					transcript = parseTranscript(readTail(filePath, TAIL_BYTES)),
				}
				cache[filePath] = read
			end

			local transcript = (read :: Read).transcript
			local branch = transcript.branch

			if not branch or not transcript.cwd or DEFAULT_BRANCHES[branch] then
				continue
			end

			local process = if live then live[id] else nil
			local state: SessionState = transcript.state

			-- A busy process is mid-turn whatever the transcript last
			-- recorded, and an idle or waiting one has left you the move. With
			-- process records to go by, a session with no process can't be
			-- working, whatever its last turn says.
			if process and process.status == "busy" then
				state = "working"
			elseif (process and process.status ~= "unknown") or (live and not process) then
				state = "waiting"
			end

			table.insert(sessions, {
				id = id,
				cwd = transcript.cwd :: string,
				branch = branch,
				title = (if process then process.name else nil) or transcript.title,
				state = state,
				isLive = if live then process ~= nil else nil,
				lastMessage = transcript.lastMessage,
				updatedAt = modified,
			})
		end
	end

	return sessions
end

return listSessionsAsync
