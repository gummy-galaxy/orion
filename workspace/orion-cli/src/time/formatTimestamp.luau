--[[
	Orion stores and sends times as UTC in ISO 8601, such as
	2026-10-31T16:00:00Z. This formats a time, given in seconds since the epoch,
	that way. Leave the time out to format the current one.
]]
local function formatTimestamp(time: number?): string
	return os.date("!%Y-%m-%dT%H:%M:%SZ", time) :: string
end

return formatTimestamp
