local json = require("@std/json")

local telemetryTypes = require("@root/telemetry/types")

type PropertyValue = telemetryTypes.PropertyValue
type QueuedEvent = telemetryTypes.QueuedEvent

local MAX_NAME_LENGTH = 64
local UUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local TIMESTAMP_PATTERN = "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.?%d*Z$"

--[[
	Checks one event's shape and returns it as the queue stores it, stamped
	with `now` when it has no time of its own. Only the shape is checked here:
	the backend checks names and properties against the catalog. A session id or
	timestamp the backend can't parse would make it refuse the whole batch, so
	those are checked strictly.
]]
local function parseQueuedEvent(value: json.Value, now: string): QueuedEvent
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
	assert(
		timestamp == nil or (type(timestamp) == "string" and timestamp:match(TIMESTAMP_PATTERN) ~= nil),
		"timestamp must be a UTC time such as 2026-10-30T12:00:00Z"
	)

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

return parseQueuedEvent
