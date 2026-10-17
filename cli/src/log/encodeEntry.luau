local json = require("@std/json")

local types = require("@root/types")

type LogEntry = types.LogEntry

local function encodeEntry(entry: LogEntry): json.Object
	local targets: json.Array = {}

	for _, target in entry.targets do
		table.insert(targets, json.object({ kind = target.kind, id = target.id }))
	end

	return json.object({
		id = entry.id,
		text = entry.text,
		time = entry.time,
		author = json.object({ kind = entry.author.kind, name = entry.author.name }),
		targets = targets,
	})
end

return encodeEntry
