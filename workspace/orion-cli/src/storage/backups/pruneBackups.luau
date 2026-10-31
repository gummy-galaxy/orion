local fs = require("@std/fs")

local getBackups = require("@root/storage/backups/getBackups")

local DAY_SECONDS = 24 * 60 * 60
local DAILY_DAYS = 30

-- Keeps every backup from the last day and the newest one from each of the last
-- 30 UTC days, and removes the rest.
local function pruneBackups(dir: string, now: number)
	local hourCutoff = os.date("!%Y%m%dT%H%M%SZ", now - DAY_SECONDS) :: string
	local dayCutoff = os.date("!%Y%m%d", now - (DAILY_DAYS - 1) * DAY_SECONDS) :: string
	local today = os.date("!%Y%m%d", now) :: string
	local current = os.date("!%Y%m%dT%H%M%SZ", now) :: string
	local keptDays: { [string]: boolean } = {}

	for _, backup in getBackups(dir) do
		local day = backup.time:sub(1, 8)
		local isInDailyRange = day >= dayCutoff and day <= today and backup.time <= current

		if backup.time >= hourCutoff and backup.time <= current then
			if isInDailyRange then
				keptDays[day] = true
			end

			continue
		end

		if isInDailyRange and not keptDays[day] then
			keptDays[day] = true
			continue
		end

		fs.remove(backup.file)
	end
end

return pruneBackups
