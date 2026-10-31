local test = require("@std/test")

local splitTelemetryBatches = require("@root/telemetry/splitTelemetryBatches")
local telemetryTypes = require("@root/telemetry/types")

type Limits = telemetryTypes.Limits
type PropertyValue = telemetryTypes.PropertyValue
type QueuedEvent = telemetryTypes.QueuedEvent

local LIMITS: Limits = { maxEvents = 100, maxBytes = 64 * 1024 }

local function events(count: number, properties: { [string]: PropertyValue }?): { QueuedEvent }
	local list: { QueuedEvent } = {}

	for _ = 1, count do
		table.insert(list, { name = "app_started", timestamp = "2026-10-30T12:00:00Z", properties = properties or {} })
	end

	return list
end

test.case("batches hold at most 100 events", function(assert)
	local batches = splitTelemetryBatches(events(250), LIMITS)

	assert.eq(#batches, 3)
	assert.eq(#batches[1], 100)
	assert.eq(#batches[2], 100)
	assert.eq(#batches[3], 50)
end)

test.case("large events split into batches the backend accepts", function(assert)
	local batches = splitTelemetryBatches(events(40, { flags = string.rep("x", 4000) }), LIMITS)

	assert.eq(#batches > 1, true)
	for _, batch in batches do
		assert.eq(#batch * 4000 < 64 * 1024, true)
	end
end)

test.case("batches follow the limits the backend publishes", function(assert)
	local batches = splitTelemetryBatches(events(25), { maxEvents = 10, maxBytes = 64 * 1024 })

	assert.eq(#batches, 3)
	assert.eq(#batches[3], 5)
end)

test.case("no events make no batches", function(assert)
	assert.eq(#splitTelemetryBatches({}, LIMITS), 0)
end)
