local fs = require("@std/fs")
local json = require("@std/json")

local claudeTypes = require("@root/sources/claude/types")
local isProcessAlive = require("@root/common/process/isProcessAlive")
local types = require("@root/types")

type LiveSession = claudeTypes.LiveSession
type CommandRunner = types.CommandRunner

--[[
	Running Claude Code processes by session id, or nil when this Claude Code
	keeps no records of them. Each process writes `sessions/<pid>.json` with its
	session and status, and a record whose process has exited is stale. Only
	the `.json` records are read, never the key files beside them.
]]
local function readLiveSessions(dir: string, run: CommandRunner): { [string]: LiveSession }?
	local folder = `{dir}/sessions`

	if not fs.exists(folder) then
		return nil
	end

	local live: { [string]: LiveSession } = {}

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

		if record and type(pid) == "number" and type(sessionId) == "string" and isProcessAlive(pid, run) then
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
