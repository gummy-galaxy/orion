local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local readTelemetryConsent = require("@root/telemetry/readTelemetryConsent")
local testing = require("@root/testing")
local writeTelemetryConsent = require("@root/telemetry/writeTelemetryConsent")

test.case("a machine with no telemetry.json is undecided", function(assert)
	local root = testing.directory("telemetry-undecided")

	assert.eq(readTelemetryConsent(root).choice, "undecided")
	assert.eq(getTelemetryStatus(root, {}).enabled, false)
end)

test.case("opting in creates an install id and keeps it until opting out", function(assert)
	local root = testing.directory("telemetry-opt-in")

	local first = writeTelemetryConsent(root, true)
	assert.eq(first.choice, "on")
	assert.eq(testing.isRandomId(first.installId), true)
	assert.eq(writeTelemetryConsent(root, true).installId, first.installId)
	assert.eq(readTelemetryConsent(root).installId, first.installId)
	assert.eq(getTelemetryStatus(root, {}).enabled, true)

	local off = writeTelemetryConsent(root, false)
	assert.eq(off.choice, "off")
	assert.eq(off.installId, nil)
	assert.eq(readTelemetryConsent(root).installId, nil)
	assert.neq(writeTelemetryConsent(root, true).installId, first.installId)
end)

test.case("an override keeps an opted-in machine from sending", function(assert)
	local root = testing.directory("telemetry-override")
	writeTelemetryConsent(root, true)

	local status = getTelemetryStatus(root, { DO_NOT_TRACK = "1" })

	assert.eq(status.choice, "on")
	assert.eq(status.override, "DO_NOT_TRACK")
	assert.eq(status.enabled, false)
end)

test.case("an unreadable or half-written telemetry.json reads as undecided", function(assert)
	local root = testing.directory("telemetry-broken")
	fs.createDirectory(root, { makeParents = true })

	for _, text in { "{", '{"choice":"on"}', '{"choice":"maybe"}', "[]" } do
		fs.writeStringToFile(path.join(root, "telemetry.json"), text)
		assert.eq(readTelemetryConsent(root).choice, "undecided")
	end
end)
