local fs = require("@std/fs")
local json = require("@std/json")

local claudeTypes = require("@root/adapters/claude/types")
local types = require("@root/types")

type LiveSession = claudeTypes.LiveSession
type CommandRunner = types.CommandRunner

-- Running Claude Code processes by session id. Each one writes `sessions/<pid>.json` with its session and whether
-- it's busy, and a record whose process has exited is stale. Only the `.json` records are read.
local function readLiveSessions(dir: string, run: CommandRunner): { [string]: LiveSession }
	local folder = `{dir}/sessions`
	local live: { [string]: LiveSession } = {}

	if not fs.exists(folder) then
		return live
	end

	for _, entry in fs.listDirectory(folder) do
		if entry.type ~= "file" or not entry.name:match("^%d+%.json$") then
			continue
		end

		local succeeded, decoded = pcall(function()
			return json.deserialize(fs.readFileToString(`{folder}/{entry.name}`))
		end)
		local record = if succeeded then json.asObject(decoded) else nil
		local pid = if record then record.pid else nil
		local sessionId = if record then record.sessionId else nil

		if
			record
			and type(pid) == "number"
			and type(sessionId) == "string"
			and run({ "kill", "-0", tostring(pid) }).ok
		then
			live[sessionId] = {
				pid = pid,
				status = if type(record.status) == "string" then record.status else "unknown",
				name = if type(record.name) == "string" then record.name else nil,
			}
		end
	end

	return live
end

return readLiveSessions
