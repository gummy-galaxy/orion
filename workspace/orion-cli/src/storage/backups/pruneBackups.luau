local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local getBackups = require("@root/storage/backups/getBackups")
local readRevisions = require("@root/storage/backups/readRevisions")

local DAY_SECONDS = 24 * 60 * 60
local DAILY_DAYS = 30
local KEEP_NEWEST = 200

-- Drops the revision log's lines for revisions with no backup left, keeping
-- those newer than every backup, such as the current revision's.
local function pruneRevisions(dir: string, kept: { [number]: boolean }, newest: number)
	local entries = readRevisions(dir)
	local revisions: { number } = {}
	local dropped = false

	for revision in entries do
		if kept[revision] or revision > newest then
			table.insert(revisions, revision)
		else
			dropped = true
		end
	end

	if not dropped then
		return
	end

	table.sort(revisions)
	local lines: { string } = {}

	for _, revision in revisions do
		local entry = entries[revision]
		local object = json.object({ revision = entry.revision, time = entry.time, by = entry.by })
		object.command = entry.command
		table.insert(lines, json.serialize(object) .. "\n")
	end

	fs.writeStringToFile(path.join(dir, fileNames.backups, fileNames.revisions), table.concat(lines))
end

-- Keeps the newest 200 backups and the newest one from each of the last 30
-- UTC days, and removes the rest along with their lines in the revision log.
local function pruneBackups(dir: string, now: number)
	local dayCutoff = os.date("!%Y%m%d", now - (DAILY_DAYS - 1) * DAY_SECONDS) :: string
	local today = os.date("!%Y%m%d", now) :: string
	local current = os.date("!%Y%m%dT%H%M%SZ", now) :: string
	local keptDays: { [string]: boolean } = {}
	local kept: { [number]: boolean } = {}
	local newest = -1

	for index, backup in getBackups(dir) do
		local day = backup.time:sub(1, 8)
		local isInDailyRange = day >= dayCutoff and day <= today and backup.time <= current
		local keep = index <= KEEP_NEWEST

		if isInDailyRange and not keptDays[day] then
			keptDays[day] = true
			keep = true
		end

		if keep then
			kept[backup.revision] = true
			newest = math.max(newest, backup.revision)
		else
			fs.remove(backup.file)
		end
	end

	pruneRevisions(dir, kept, newest)
end

return pruneBackups
