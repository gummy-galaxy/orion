local types = require("@root/types")

type LogEntry = types.LogEntry

-- One entry as a line: when it was logged, who logged it, the cards it's
-- attached to, and its text.
local function formatEntry(entry: LogEntry, withTargets: boolean): string
	local author = if entry.author.kind == "agent" then `{entry.author.name} (agent)` else entry.author.name
	local parts = { entry.time, author }

	if withTargets then
		local ids: { string } = {}

		for _, target in entry.targets do
			table.insert(ids, target.id)
		end

		table.insert(parts, if #ids > 0 then table.concat(ids, ", ") else "canvas")
	end

	local text = entry.text:gsub("\n", "\n    ")
	table.insert(parts, text)
	return table.concat(parts, "  ")
end

return formatEntry
