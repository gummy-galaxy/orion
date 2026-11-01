local test = require("@std/test")

local createPerformanceSummaries = require("@root/server/createPerformanceSummaries")
local deriveTimed = require("@root/server/deriveTimed")
local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local getBuild = require("@root/common/getBuild")
local telemetryConstants = require("@root/telemetry/constants")
local testing = require("@root/testing")
local writeTelemetryConsent = require("@root/telemetry/writeTelemetryConsent")

local NOW = "2026-10-30T12:00:00Z"
local RELEASE = getBuild("e87813e")

test.case("each timed metric is summarized with the canvas size, then starts over", function(assert)
	local root = testing.directory("performance-summaries")
	writeTelemetryConsent(root, true)
	local performanceSummaries = createPerformanceSummaries(root, { environment = {}, build = RELEASE })

	deriveTimed(
		testing.createDoc({ testing.task("a", "First", "todo"), testing.task("b", "Second", "todo") }),
		performanceSummaries
	)
	performanceSummaries.record("server_flush", 8)
	performanceSummaries.record("server_flush", 20)

	assert.eq(performanceSummaries.queue(), 2)

	local events = drainTelemetryQueue(root, NOW)
	assert.eq(events[1].properties.metric, "derive")
	assert.eq(events[1].properties.sample_count, 1)
	assert.eq(events[1].properties.card_count, 2)
	assert.eq(events[2].properties.metric, "server_flush")
	assert.eq(events[2].properties.max_ms, 20)
	assert.eq(performanceSummaries.queue(), 0)
end)

test.case("closing queues the last stretch once", function(assert)
	local root = testing.directory("performance-summaries-close")
	writeTelemetryConsent(root, true)
	local performanceSummaries = createPerformanceSummaries(root, { environment = {}, build = RELEASE })

	performanceSummaries.record("derive", 3)
	performanceSummaries.close()
	performanceSummaries.record("derive", 4)
	performanceSummaries.close()

	local events = drainTelemetryQueue(root, NOW)
	assert.eq(#events, 1)
	assert.eq(events[1].properties.p50_ms, 3)
end)

test.case("samples past the cap still count toward sample_count", function(assert)
	local root = testing.directory("performance-summaries-cap")
	writeTelemetryConsent(root, true)
	local performanceSummaries = createPerformanceSummaries(root, { environment = {}, build = RELEASE })

	for _ = 1, telemetryConstants.MAX_PERFORMANCE_SAMPLES + 5 do
		performanceSummaries.record("derive", 1)
	end
	performanceSummaries.queue()

	assert.eq(drainTelemetryQueue(root, NOW)[1].properties.sample_count, telemetryConstants.MAX_PERFORMANCE_SAMPLES + 5)
end)
