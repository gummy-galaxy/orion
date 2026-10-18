local fs = require("@std/fs")
local json = require("@std/json")

local getLogPath = require("@root/log/getLogPath")
local getStringField = require("@root/getStringField")
local types = require("@root/types")

type LogEntry = types.LogEntry
type LogTarget = types.LogTarget

local function decodeEntry(object: json.Object): LogEntry
	local id = getStringField(object.id)
	local text = getStringField(object.text)
	local time = getStringField(object.time)
	local author = json.asObject(object.author)
	local kind = if author then getStringField(author.kind) else nil
	local name = if author then getStringField(author.name) else nil
	assert(id and text and time and name and (kind == "person" or kind == "agent"), "missing log entry fields")

	local targets: { LogTarget } = {}

	for _, raw in json.asArray(object.targets) or {} do
		local target = json.asObject(raw)
		local targetKind = if target then getStringField(target.kind) else nil
		local targetId = if target then getStringField(target.id) else nil
		assert(targetKind == "card" and targetId, `invalid target on log entry {id}`)
		local logTarget: LogTarget = { kind = "card", id = targetId }
		table.insert(targets, logTarget)
	end

	return {
		id = id,
		text = text,
		time = time,
		author = { kind = if kind == "agent" then "agent" else "person", name = name },
		targets = targets,
	}
end

-- Every entry in the order it was appended. A last line without its newline is an append that never finished,
-- so it isn't in the log yet.
local function readLog(dir: string): { LogEntry }
	local file = getLogPath(dir)
	local entries: { LogEntry } = {}

	if not fs.exists(file) then
		return entries
	end

	local lineNumber = 0

	for line in fs.readFileToString(file):gmatch("([^\n]*)\n") do
		lineNumber += 1

		if line ~= "" then
			local object = json.asObject(json.deserialize(line) :: json.Value)
			assert(object, `log line {lineNumber} is not an object`)
			table.insert(entries, decodeEntry(object))
		end
	end

	return entries
end

return readLog
