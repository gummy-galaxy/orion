-- Reads an ISO 8601 date or date-time and returns it as UTC in the form Orion
-- stores, such as 2026-10-12T07:00:00Z. A date alone means the start of that
-- day, and a date-time without an offset is local time.

local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local SECONDS_PER_DAY = 86400
local EXAMPLE = "2026-10-12, 2026-10-12T17:00, or 2026-10-12T17:00:00Z"

-- Days from 1970-01-01 to a civil date in the proleptic Gregorian calendar.
local function daysFromCivil(year: number, month: number, day: number): number
	local shifted = if month <= 2 then year - 1 else year
	local era = shifted // 400
	local yearOfEra = shifted - era * 400
	local dayOfYear = (153 * ((month + 9) % 12) + 2) // 5 + day - 1
	local dayOfEra = yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear

	return era * 146097 + dayOfEra - 719468
end

local function daysInMonth(year: number, month: number): number
	local leap = (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0

	if month == 2 and leap then
		return 29
	end

	return DAYS_IN_MONTH[month]
end

-- The local clock's offset from UTC at an instant, in seconds.
local function localOffsetAt(epoch: number): number
	local text = os.date("%z", epoch) :: string
	local sign, hours, minutes = text:match("^([+-])(%d%d)(%d%d)$")
	assert(sign, `could not read the local time offset from {text}`)
	local seconds = (tonumber(hours) :: number) * 3600 + (tonumber(minutes) :: number) * 60

	return if sign == "-" then -seconds else seconds
end

-- Returns whether the zone text is one ISO 8601 allows, and its offset from UTC
-- when it names one.
local function readZone(text: string): (boolean, number?)
	if text == "" then
		return true, nil
	end

	if text == "Z" then
		return true, 0
	end

	local sign, hours, minutes = text:match("^([+-])(%d%d):?(%d%d)$")

	if not sign then
		sign, hours = text:match("^([+-])(%d%d)$")
		minutes = "00"
	end

	if not sign or not hours or not minutes then
		return false, nil
	end

	local seconds = (tonumber(hours) :: number) * 3600 + (tonumber(minutes) :: number) * 60

	return true, if sign == "-" then -seconds else seconds
end

local function parseUntil(text: string): string
	local datePart, restMatch = text:match("^(%d%d%d%d%-%d%d%-%d%d)(.*)$")
	assert(datePart, `--until takes an ISO 8601 date or date-time, such as {EXAMPLE}`)
	local rest: string = restMatch or ""

	local yearText, monthText, dayText = datePart:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	local year = tonumber(yearText) :: number
	local month = tonumber(monthText) :: number
	local day = tonumber(dayText) :: number
	assert(month >= 1 and month <= 12, `--until has an invalid month in {text}`)
	assert(day >= 1 and day <= daysInMonth(year, month), `--until has an invalid day in {text}`)

	local hour, minute, second = 0, 0, 0
	local zone = ""

	if rest ~= "" then
		local hourText, minuteText, timeTail = rest:match("^T(%d%d):(%d%d)(.*)$")
		local shapeMessage = `--until takes an ISO 8601 date or date-time, such as {EXAMPLE}`
		assert(hourText, shapeMessage)
		assert(minuteText, shapeMessage)
		hour = tonumber(hourText) :: number
		minute = tonumber(minuteText) :: number
		assert(hour <= 23 and minute <= 59, `--until has an invalid time in {text}`)

		local secondText = (timeTail or ""):match("^:(%d%d)")
		local tail: string = timeTail or ""

		if secondText then
			second = tonumber(secondText) :: number
			assert(second <= 59, `--until has an invalid time in {text}`)
			tail = tail:sub(4)
		end

		-- Fractions of a second never change the minute a card wakes in, so
		-- they're dropped.
		zone = tail:gsub("^%.%d+", "")
	end

	local valid, offset = readZone(zone)
	assert(valid, `--until has an invalid time zone in {text}`)

	local utc = daysFromCivil(year, month, day) * SECONDS_PER_DAY + hour * 3600 + minute * 60 + second

	-- A time without an offset is the local clock's time, so the offset in
	-- effect then comes off.
	utc -= if offset then offset else localOffsetAt(utc)

	return os.date("!%Y-%m-%dT%H:%M:%SZ", utc) :: string
end

return parseUntil
