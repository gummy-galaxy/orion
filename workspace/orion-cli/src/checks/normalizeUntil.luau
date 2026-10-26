-- Turns the end of a snooze into the UTC time format the CLI records, so times
-- compare as text. Takes a UTC time such as 2026-10-14T18:00:00Z, with or
-- without fractions of a second, or a date, which means the start of that day
-- in UTC.
local function normalizeUntil(value: string): string
	local date = value:match("^(%d%d%d%d%-%d%d%-%d%d)$")

	if date then
		return `{date}T00:00:00Z`
	end

	local time = value:match("^(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d)%.?%d*Z$")
	assert(time, `"{value}" isn't a UTC time such as 2026-10-14T18:00:00Z or a date such as 2026-10-14`)
	return `{time}Z`
end

return normalizeUntil
