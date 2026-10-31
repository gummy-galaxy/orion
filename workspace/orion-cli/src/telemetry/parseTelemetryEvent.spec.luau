local json = require("@std/json")
local test = require("@std/test")

local parseTelemetryEvent = require("@root/telemetry/parseTelemetryEvent")

local NOW = "2026-10-30T12:00:00Z"
local SESSION_ID = "0b7e3a52-5d43-4c8e-8f0e-6d3e1f2a9c11"

local function parse(text: string)
	return parseTelemetryEvent(json.deserialize(text) :: json.Value, NOW)
end

test.case("an event keeps its session, time, and flat properties", function(assert)
	local event = parse(
		`\{"name":"app_started","sessionId":"{SESSION_ID}","timestamp":"2026-10-30T11:59:58.250Z",`
			.. '"properties":{"startup_ms":812.5,"card_count":40}}'
	)

	assert.eq(event.name, "app_started")
	assert.eq(event.sessionId, SESSION_ID)
	assert.eq(event.timestamp, "2026-10-30T11:59:58.250Z")
	assert.eq(event.properties.startup_ms, 812.5)
	assert.eq(event.properties.card_count, 40)
end)

test.case("an event without a time is stamped with now", function(assert)
	local event = parse('{"name":"telemetry_opted_in"}')

	assert.eq(event.timestamp, NOW)
	assert.eq(event.sessionId, nil)
	assert.eq(next(event.properties), nil)
end)

test.case("shapes the backend would refuse a whole batch over are rejected", function(assert)
	for _, text in
		{
			'"app_started"',
			'{"name":"App Started"}',
			'{"name":"app_started","sessionId":"launch-1"}',
			'{"name":"app_started","timestamp":"yesterday"}',
			'{"name":"app_started","properties":[]}',
			'{"name":"app_started","properties":{"nested":{"a":1}}}',
		}
	do
		assert.eq(pcall(parse, text), false)
	end
end)
