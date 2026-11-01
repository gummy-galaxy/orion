local test = require("@std/test")

local getTelemetryOverride = require("@root/telemetry/getTelemetryOverride")

test.case("DO_NOT_TRACK turns telemetry off for any value but empty or 0", function(assert)
	assert.eq(getTelemetryOverride({ DO_NOT_TRACK = "1" }), "DO_NOT_TRACK")
	assert.eq(getTelemetryOverride({ DO_NOT_TRACK = "true" }), "DO_NOT_TRACK")
	assert.eq(getTelemetryOverride({ DO_NOT_TRACK = "0" }), nil)
	assert.eq(getTelemetryOverride({ DO_NOT_TRACK = "" }), nil)
end)

test.case("ORION_TELEMETRY turns telemetry off only when it says so", function(assert)
	assert.eq(getTelemetryOverride({ ORION_TELEMETRY = "0" }), "ORION_TELEMETRY")
	assert.eq(getTelemetryOverride({ ORION_TELEMETRY = "OFF" }), "ORION_TELEMETRY")
	assert.eq(getTelemetryOverride({ ORION_TELEMETRY = "1" }), nil)
	assert.eq(getTelemetryOverride({}), nil)
end)
