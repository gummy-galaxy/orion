local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getBackups = require("@root/storage/backups/getBackups")
local loadDoc = require("@root/storage/canvases/loadDoc")
local readRevisions = require("@root/storage/backups/readRevisions")
local storeTypes = require("@root/storage/types")

type Context = context.Context
type RevisionEntry = storeTypes.RevisionEntry

type Row = { revision: number, time: string?, entry: RevisionEntry?, current: boolean }

-- Backup file names carry a compact UTC time such as 20261017T164600Z; output
-- spells it in RFC 3339.
local function formatTime(compact: string): string
	local year, month, day, hour, minute, second = compact:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)Z$")
	return `{year}-{month}-{day}T{hour}:{minute}:{second}Z`
end

-- The current revision, then each one with a backup, newest first. A revision
-- the log doesn't know is timed by when its backup was saved.
local function getRows(dir: string): { Row }
	local entries = readRevisions(dir)
	local revision = loadDoc(dir).revision
	local rows: { Row } = { { revision = revision, entry = entries[revision], current = true } }
	local seen: { [number]: boolean } = { [revision] = true }

	for _, backup in getBackups(dir) do
		if not seen[backup.revision] then
			seen[backup.revision] = true
			table.insert(rows, {
				revision = backup.revision,
				time = formatTime(backup.time),
				entry = entries[backup.revision],
				current = false,
			})
		end
	end

	return rows
end

local function describeWriter(entry: RevisionEntry?): string
	if entry == nil then
		return "unknown"
	end

	return if entry.command then `{entry.by} {entry.command}` else entry.by
end

return table.freeze({
	help = "List the revisions you can jump to, newest first, with when and how each was made",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local rows = getRows(options.dir)

		if options.asJson then
			local values: json.Array = {}

			for _, row in rows do
				local value = json.object({ revision = row.revision, current = row.current })
				value.time = if row.entry then row.entry.time else row.time
				value.by = if row.entry then row.entry.by else nil
				value.command = if row.entry then row.entry.command else nil
				table.insert(values, value)
			end

			options.write(json.serialize(values, true))
		else
			local lines: { string } = {}

			for _, row in rows do
				local time = if row.entry then row.entry.time else row.time or "unknown time"
				local suffix = if row.current then "  (current)" else ""
				table.insert(lines, `r{row.revision}  {time}  {describeWriter(row.entry)}{suffix}`)
			end

			options.write(table.concat(lines, "\n"))
		end
	end,
})
