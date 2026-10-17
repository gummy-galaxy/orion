local json = require("@std/json")
local test = require("@std/test")

local parseUntil = require("@root/time/parseUntil")
local store = require("@root/store")
local testing = require("@root/testing")

-- The harness's clock reads 2026-10-04, so these times are in the future.
local LATER = "2026-10-12T17:00:00Z"

test.case("snooze hides an item from next until it wakes and leaves its dependents blocked", function(assert)
	local _, run = testing.createHarness("snooze-ready")
	assert.strContains(run({ "card", "snooze", "ci", "--until", LATER }), "Snoozed 1 item until 2026-10-12T17:00:00Z")
	assert.strNotContains(run({ "next" }), "ci")
	assert.strContains(run({ "node", "show", "pub" }), "waits on ci")
	assert.strContains(run({ "node", "show", "pub" }), "status   blocked")
	assert.strContains(run({ "node", "query", "--where", `snoozed = "true"` }), "ci")
	assert.strNotContains(run({ "node", "query", "--where", `snoozed = "true"` }), "pub")
end)

test.case("snooze reports the time it wakes in show and JSON", function(assert)
	local _, run = testing.createHarness("snooze-show")
	-- A date alone wakes at local midnight, so the UTC time depends on the machine's zone.
	local wakes = parseUntil("2026-10-12")
	run({ "card", "snooze", "ci", "--until", "2026-10-12" })
	assert.strContains(run({ "node", "show", "ci" }), `snoozed  until {wakes}`)
	local shown = json.asObject(json.deserialize(run({ "node", "show", "ci", "--json" })) :: json.Value)
	assert.eq(shown and shown.snoozedUntil, wakes)
end)

test.case("snooze takes --where and --json and reports the target", function(assert)
	local dir, run = testing.createHarness("snooze-where")
	local output = json.asObject(
		json.deserialize(run({ "card", "snooze", "--where", `label ~ "publish"`, "--until", LATER, "--json" })) :: json.Value
	) :: json.Object
	assert.eq(output.action, "snooze")
	assert.eq(output["until"], LATER)
	assert.eq(output.revision, 1)
	assert.eq(store.load(dir).nodes[3].data.snoozedUntil, LATER)
end)

test.case("snooze --dry-run previews without writing", function(assert)
	local dir, run = testing.createHarness("snooze-dry")
	assert.strContains(
		run({ "card", "snooze", "ci", "--until", LATER, "--dry-run" }),
		"Would snooze 1 item until 2026-10-12T17:00:00Z at revision 0"
	)
	assert.eq(store.load(dir).revision, 0)
	assert.eq(store.load(dir).nodes[2].data.snoozedUntil, nil)
end)

test.case("snooze refuses past times, groups, notes, and bad dates", function(assert)
	local _, run = testing.createHarness("snooze-refuse")
	assert.throws(function()
		run({ "card", "snooze", "ci", "--until", "2026-10-01" })
	end)
	assert.throws(function()
		run({ "card", "snooze", "ws", "--until", LATER })
	end)
	assert.throws(function()
		run({ "card", "snooze", "ci", "--until", "next week" })
	end)
	assert.throws(function()
		run({ "card", "snooze", "ci" })
	end)
end)

test.case("unsnooze wakes items at once and next lists them again", function(assert)
	local dir, run = testing.createHarness("unsnooze")
	run({ "card", "snooze", "ci", "--until", LATER })
	assert.strContains(run({ "card", "unsnooze", "ci" }), "Woke 1 item")
	assert.eq(store.load(dir).nodes[2].data.snoozedUntil, nil)
	assert.strContains(run({ "next" }), "ci")
end)

test.case("unsnooze --where selects the snoozed items", function(assert)
	local _, run = testing.createHarness("unsnooze-where")
	run({ "card", "snooze", "ci", "--until", LATER })
	assert.strContains(run({ "card", "unsnooze", "--where", `snoozed = "true"`, "--dry-run" }), "Would wake 1 item")
end)
