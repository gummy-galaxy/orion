local fs = require("@std/fs")
local json = require("@std/json")

local encodeEntry = require("@root/log/encodeEntry")
local getLogPath = require("@root/log/getLogPath")
local readLog = require("@root/log/readLog")
local store = require("@root/store")
local types = require("@root/types")

type Doc = types.Doc
type LogEntry = types.LogEntry

-- Appends one entry under the workspace lock. `build` gets the entries so far and the latest document, and returns
-- the entry to add. Only the log file changes, so the canvas revision stays the same.
local function appendLog(dir: string, build: ({ LogEntry }, Doc) -> LogEntry): LogEntry
	return store.withLock(dir, function(): LogEntry
		local entry = build(readLog(dir), store.load(dir))
		local line = json.serialize(encodeEntry(entry)) .. "\n"
		local handle = fs.open(getLogPath(dir), "a")
		local didWrite, message = pcall(fs.write, handle, line)
		fs.close(handle)

		if not didWrite then
			error(message, 0)
		end

		return entry
	end)
end

return appendLog
