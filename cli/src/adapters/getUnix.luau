local function getUnix(timestamp: string): number
	local year, month, day, hour, minute, second = timestamp:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")

	if not year then
		return os.time()
	end

	local localTime = os.time({
		year = tonumber(year) :: number,
		month = tonumber(month) :: number,
		day = tonumber(day) :: number,
		hour = tonumber(hour) :: number,
		min = tonumber(minute) :: number,
		sec = tonumber(second) :: number,
	})
	local utcDate = os.date("!*t", localTime)
	return localTime
		+ os.difftime(
			localTime,
			os.time({
				year = utcDate.year,
				month = utcDate.month,
				day = utcDate.day,
				hour = utcDate.hour,
				min = utcDate.min,
				sec = utcDate.sec,
			})
		)
end

return getUnix
