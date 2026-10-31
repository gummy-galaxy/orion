local test = require("@std/test")

local deriveTimed = require("@root/server/deriveTimed")
local getBuild = require("@root/telemetry/getBuild")
local performanceSummaries = require("@root/server/performanceSummaries")
local takeQueue = require("@root/telemetry/takeQueue")
local testing = require("@root/testing")
local writeConsent = require("@root/telemetry/writeConsent")

local NOW = "2026-10-30T12:00:00Z"
local RELEASE = getBuild("e87813e")

test.case("each timed metric is summarized with the canvas size, then starts over", function(assert)
	local root = testing.directory("performance-summaries")
	writeConsent(root, true)
	local summaries = performanceSummaries.create(root, { environment = {}, build = RELEASE })

	deriveTimed(
		testing.createDoc({ testing.task("a", "First", "todo"), testing.task("b", "Second", "todo") }),
		summaries
	)
	summaries.record("server_flush", 8)
	summaries.record("server_flush", 20)

	assert.eq(summaries.queue(), 2)

	local events = takeQueue(root, NOW)
	assert.eq(events[1].properties.metric, "derive")
	assert.eq(events[1].properties.sample_count, 1)
	assert.eq(events[1].properties.card_count, 2)
	assert.eq(events[2].properties.metric, "server_flush")
	assert.eq(events[2].properties.max_ms, 20)
	assert.eq(summaries.queue(), 0)
end)

test.case("closing queues the last stretch once", function(assert)
	local root = testing.directory("performance-summaries-close")
	writeConsent(root, true)
	local summaries = performanceSummaries.create(root, { environment = {}, build = RELEASE })

	summaries.record("derive", 3)
	summaries.close()
	summaries.record("derive", 4)
	summaries.close()

	local events = takeQueue(root, NOW)
	assert.eq(#events, 1)
	assert.eq(events[1].properties.p50_ms, 3)
end)

test.case("samples past the cap still count toward sample_count", function(assert)
	local root = testing.directory("performance-summaries-cap")
	writeConsent(root, true)
	local summaries = performanceSummaries.create(root, { environment = {}, build = RELEASE })

	for _ = 1, performanceSummaries.MAX_SAMPLES + 5 do
		summaries.record("derive", 1)
	end
	summaries.queue()

	assert.eq(takeQueue(root, NOW)[1].properties.sample_count, performanceSummaries.MAX_SAMPLES + 5)
end)
