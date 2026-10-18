local types = require("@root/types")

type LogEntry = types.LogEntry

-- The entries attached to one card, in the order they were appended.
local function getCardEntries(entries: { LogEntry }, id: string): { LogEntry }
	local found: { LogEntry } = {}

	for _, entry in entries do
		for _, target in entry.targets do
			if target.id == id then
				table.insert(found, entry)
				break
			end
		end
	end

	return found
end

return getCardEntries
