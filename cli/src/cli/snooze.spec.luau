local json = require("@std/json")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

-- The harness's clock reads 2026-10-04, so these times are in the future.
local LATER = "2026-10-12T17:00:00Z"

test.case("snooze hides an item from ready until it wakes and leaves its dependents blocked", function(assert)
	local _, run = testing.createHarness("snooze-ready")
	assert.strContains(run({ "snooze", "ci", "--until", LATER }), "Snoozed 1 item until 2026-10-12T17:00:00Z")
	assert.strNotContains(run({ "ready" }), "ci")
	assert.strContains(run({ "show", "pub" }), "waits on ci")
	assert.strContains(run({ "show", "pub" }), "status   blocked")
	assert.strContains(run({ "query", "--where", `snoozed = "true"` }), "ci")
	assert.strNotContains(run({ "query", "--where", `snoozed = "true"` }), "pub")
end)

test.case("snooze reports the time it wakes in show and JSON", function(assert)
	local _, run = testing.createHarness("snooze-show")
	run({ "snooze", "ci", "--until", "2026-10-12" })
	assert.strContains(run({ "show", "ci" }), "snoozed  until 2026-10-12T07:00:00Z")
	local shown = json.asObject(json.deserialize(run({ "show", "ci", "--json" })) :: json.Value)
	assert.eq(shown and shown.snoozedUntil, "2026-10-12T07:00:00Z")
end)

test.case("snooze takes --where and --json and reports the target", function(assert)
	local dir, run = testing.createHarness("snooze-where")
	local output = json.asObject(
		json.deserialize(run({ "snooze", "--where", `label ~ "publish"`, "--until", LATER, "--json" })) :: json.Value
	) :: json.Object
	assert.eq(output.action, "snooze")
	assert.eq(output["until"], LATER)
	assert.eq(output.revision, 1)
	assert.eq(store.load(dir).nodes[3].data.snoozedUntil, LATER)
end)

test.case("snooze --dry-run previews without writing", function(assert)
	local dir, run = testing.createHarness("snooze-dry")
	assert.strContains(
		run({ "snooze", "ci", "--until", LATER, "--dry-run" }),
		"Would snooze 1 item until 2026-10-12T17:00:00Z at revision 0"
	)
	assert.eq(store.load(dir).revision, 0)
	assert.eq(store.load(dir).nodes[2].data.snoozedUntil, nil)
end)

test.case("snooze refuses past times, groups, notes, and bad dates", function(assert)
	local _, run = testing.createHarness("snooze-refuse")
	assert.throws(function()
		run({ "snooze", "ci", "--until", "2026-10-01" })
	end)
	assert.throws(function()
		run({ "snooze", "ws", "--until", LATER })
	end)
	assert.throws(function()
		run({ "snooze", "ci", "--until", "next week" })
	end)
	assert.throws(function()
		run({ "snooze", "ci" })
	end)
end)

test.case("unsnooze wakes items at once and ready lists them again", function(assert)
	local dir, run = testing.createHarness("unsnooze")
	run({ "snooze", "ci", "--until", LATER })
	assert.strContains(run({ "unsnooze", "ci" }), "Woke 1 item")
	assert.eq(store.load(dir).nodes[2].data.snoozedUntil, nil)
	assert.strContains(run({ "ready" }), "ci")
end)

test.case("unsnooze --where selects the snoozed items", function(assert)
	local _, run = testing.createHarness("unsnooze-where")
	run({ "snooze", "ci", "--until", LATER })
	assert.strContains(run({ "unsnooze", "--where", `snoozed = "true"`, "--dry-run" }), "Would wake 1 item")
end)
