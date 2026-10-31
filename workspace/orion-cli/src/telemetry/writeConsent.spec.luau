local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local getStatus = require("@root/telemetry/getStatus")
local readConsent = require("@root/telemetry/readConsent")
local testing = require("@root/testing")
local writeConsent = require("@root/telemetry/writeConsent")

test.case("a machine with no telemetry.json is undecided", function(assert)
	local root = testing.directory("telemetry-undecided")

	assert.eq(readConsent(root).choice, "undecided")
	assert.eq(getStatus(root, {}).enabled, false)
end)

test.case("opting in creates an install id and keeps it until opting out", function(assert)
	local root = testing.directory("telemetry-opt-in")

	local first = writeConsent(root, true)
	assert.eq(first.choice, "on")
	assert.eq(testing.isRandomId(first.installId), true)
	assert.eq(writeConsent(root, true).installId, first.installId)
	assert.eq(readConsent(root).installId, first.installId)
	assert.eq(getStatus(root, {}).enabled, true)

	local off = writeConsent(root, false)
	assert.eq(off.choice, "off")
	assert.eq(off.installId, nil)
	assert.eq(readConsent(root).installId, nil)
	assert.neq(writeConsent(root, true).installId, first.installId)
end)

test.case("an override keeps an opted-in machine from sending", function(assert)
	local root = testing.directory("telemetry-override")
	writeConsent(root, true)

	local status = getStatus(root, { DO_NOT_TRACK = "1" })

	assert.eq(status.choice, "on")
	assert.eq(status.override, "DO_NOT_TRACK")
	assert.eq(status.enabled, false)
end)

test.case("an unreadable or half-written telemetry.json reads as undecided", function(assert)
	local root = testing.directory("telemetry-broken")
	fs.createDirectory(root, { makeParents = true })

	for _, text in { "{", '{"choice":"on"}', '{"choice":"maybe"}', "[]" } do
		fs.writeStringToFile(path.join(root, "telemetry.json"), text)
		assert.eq(readConsent(root).choice, "undecided")
	end
end)
