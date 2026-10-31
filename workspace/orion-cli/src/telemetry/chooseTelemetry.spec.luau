local test = require("@std/test")

local chooseTelemetry = require("@root/telemetry/chooseTelemetry")
local getBuild = require("@root/telemetry/getBuild")
local takeQueue = require("@root/telemetry/takeQueue")
local testing = require("@root/testing")

local NOW = "2026-10-30T12:00:00Z"
local RELEASE = getBuild("e87813e")

test.case("opting in queues one event saying where", function(assert)
	local root = testing.directory("choose-telemetry")

	chooseTelemetry(root, true, "cli", {}, RELEASE)
	chooseTelemetry(root, true, "app", {}, RELEASE)

	local events = takeQueue(root, NOW)

	assert.eq(#events, 1)
	assert.eq(events[1].name, "telemetry_opted_in")
	assert.eq(events[1].properties.surface, "cli")
end)

test.case("opting out queues nothing", function(assert)
	local root = testing.directory("choose-telemetry-off")

	chooseTelemetry(root, false, "app", {}, RELEASE)

	assert.eq(#takeQueue(root, NOW), 0)
end)

test.case("dev builds and overrides record the choice but queue nothing", function(assert)
	local devRoot = testing.directory("choose-telemetry-dev")
	assert.eq(chooseTelemetry(devRoot, true, "app", {}, getBuild("dev")).choice, "on")
	assert.eq(#takeQueue(devRoot, NOW), 0)

	local overrideRoot = testing.directory("choose-telemetry-override")
	assert.eq(chooseTelemetry(overrideRoot, true, "cli", { DO_NOT_TRACK = "1" }, RELEASE).choice, "on")
	assert.eq(#takeQueue(overrideRoot, NOW), 0)
end)
