local json = require("@std/json")
local test = require("@std/test")

local loadDoc = require("@root/store/loadDoc")
local testing = require("@root/testing")

test.case("ci snooze, list, and unsnooze change the canvas's snoozed jobs", function(assert)
	local dir, run = testing.createHarness("ci-snooze")
	assert.eq(run({ "ci", "list" }), "No snoozed CI jobs.")

	assert.strContains(run({ "ci", "snooze", "docs", "--repo", "vocksel/orion" }), "until it passes")
	assert.strContains(
		run({ "ci", "snooze", "lint", "--repo", "vocksel/orion", "--until", "2099-01-01" }),
		"until 2099-01-01T00:00:00Z"
	)
	assert.strContains(run({ "ci", "list" }), "vocksel/orion  docs  until it passes")

	local listed = json.asArray(json.deserialize(run({ "ci", "list", "--json" })) :: json.Value) or {}
	assert.eq(#listed, 2)

	run({ "ci", "unsnooze", "docs", "--repo", "vocksel/orion" })
	local snoozes = loadDoc(dir).settings.checkSnoozes
	assert.eq(#snoozes, 1)
	assert.eq(snoozes[1].name, "lint")
end)

test.case("ci snooze needs a repository and an end in the future", function(assert)
	local _, run = testing.createHarness("ci-snooze-errors")
	assert.throwsWith("missing --repo <owner/name>", function()
		run({ "ci", "snooze", "docs" })
	end)
	assert.throwsWith("--until must be in the future", function()
		run({ "ci", "snooze", "docs", "--repo", "vocksel/orion", "--until", "2001-01-01" })
	end)
end)
