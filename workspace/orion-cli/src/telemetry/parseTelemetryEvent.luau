local json = require("@std/json")

local telemetryTypes = require("@root/telemetry/types")

type PropertyValue = telemetryTypes.PropertyValue
type QueuedEvent = telemetryTypes.QueuedEvent

local MAX_NAME_LENGTH = 64
local UUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local TIMESTAMP_PATTERN = "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)(%.?%d*)Z$"
local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- Whether a time is UTC in ISO 8601 and names a real moment, such as
-- 2026-10-30T12:00:00Z or 2026-10-30T12:00:00.250Z. The pattern alone would
-- let through a date like 2026-99-99, which the backend can't parse.
local function isTimestamp(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end

	local year, month, day, hour, minute, second, fraction = value:match(TIMESTAMP_PATTERN)

	if not year or (fraction ~= "" and not fraction:match("^%.%d+$")) then
		return false
	end

	local yearNumber, monthNumber = tonumber(year) :: number, tonumber(month) :: number
	local isLeapYear = yearNumber % 4 == 0 and (yearNumber % 100 ~= 0 or yearNumber % 400 == 0)

	if monthNumber < 1 or monthNumber > 12 then
		return false
	end

	local daysInMonth = if monthNumber == 2 and isLeapYear then 29 else DAYS_IN_MONTH[monthNumber]

	return (tonumber(day) :: number) >= 1
		and (tonumber(day) :: number) <= daysInMonth
		and (tonumber(hour) :: number) <= 23
		and (tonumber(minute) :: number) <= 59
		and (tonumber(second) :: number) <= 59
end

--[[
	Checks that one event is well formed and returns it the way the queue
	stores it. An event without a time of its own is stamped with `now`.

	This checks the form of an event, not whether it's one Orion records. The
	backend checks names and properties against the published event list, and
	it drops an unknown event on its own. A session id or timestamp it can't
	parse is different: the backend refuses the whole batch over it. So those
	two are checked in full here.
]]
local function parseTelemetryEvent(value: json.Value, now: string): QueuedEvent
	local object = assert(json.asObject(value), "an event must be an object")
	local name = object.name

	assert(
		type(name) == "string" and #name <= MAX_NAME_LENGTH and name:match("^[%l_][%l%d_]*$") ~= nil,
		"an event needs a snake_case name"
	)

	local sessionId = object.sessionId
	assert(
		sessionId == nil or (type(sessionId) == "string" and sessionId:match(UUID_PATTERN) ~= nil),
		"sessionId must be a UUID"
	)

	local timestamp = object.timestamp
	assert(timestamp == nil or isTimestamp(timestamp), "timestamp must be a UTC time such as 2026-10-30T12:00:00Z")

	local properties: { [string]: PropertyValue } = {}

	if object.properties ~= nil then
		local rawProperties = assert(json.asObject(object.properties), "properties must be an object")

		for key, property in rawProperties do
			assert(
				type(property) == "string" or type(property) == "number" or type(property) == "boolean",
				`property {key} must be a string, number, or boolean`
			)
			properties[key] = property :: PropertyValue
		end
	end

	return {
		name = name :: string,
		sessionId = sessionId :: string?,
		timestamp = (timestamp :: string?) or now,
		properties = properties,
	}
end

return parseTelemetryEvent
