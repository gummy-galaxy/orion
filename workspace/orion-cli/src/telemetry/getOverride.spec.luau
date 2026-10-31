local test = require("@std/test")

local getOverride = require("@root/telemetry/getOverride")

test.case("DO_NOT_TRACK turns telemetry off for any value but empty or 0", function(assert)
	assert.eq(getOverride({ DO_NOT_TRACK = "1" }), "DO_NOT_TRACK")
	assert.eq(getOverride({ DO_NOT_TRACK = "true" }), "DO_NOT_TRACK")
	assert.eq(getOverride({ DO_NOT_TRACK = "0" }), nil)
	assert.eq(getOverride({ DO_NOT_TRACK = "" }), nil)
end)

test.case("ORION_TELEMETRY turns telemetry off only when it says so", function(assert)
	assert.eq(getOverride({ ORION_TELEMETRY = "0" }), "ORION_TELEMETRY")
	assert.eq(getOverride({ ORION_TELEMETRY = "OFF" }), "ORION_TELEMETRY")
	assert.eq(getOverride({ ORION_TELEMETRY = "1" }), nil)
	assert.eq(getOverride({}), nil)
end)
