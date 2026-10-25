-- Names a backup after the revision it holds and the UTC second it was taken.
local function getBackupName(revision: number, now: number): string
	return `orion-r{revision}-{os.date("!%Y%m%dT%H%M%SZ", now)}.json`
end

return getBackupName
