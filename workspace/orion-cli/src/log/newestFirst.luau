local types = require("@root/types")

type LogEntry = types.LogEntry

-- Entries in the order a reader wants them: newest first, and at most `limit`
-- of them when one is given.
local function newestFirst(entries: { LogEntry }, limit: number?): { LogEntry }
	local found: { LogEntry } = {}

	for index = #entries, 1, -1 do
		if limit and #found >= limit then
			break
		end

		table.insert(found, entries[index])
	end

	return found
end

return newestFirst
