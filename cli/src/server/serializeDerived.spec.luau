local json = require("@std/json")
local test = require("@std/test")

local derive = require("@root/graph/derive")
local serializeDerived = require("@root/server/serializeDerived")
local testing = require("@root/testing")

test.case("serializeDerived writes every map as an object, even when empty", function(assert)
	local parsed = json.asObject(
		json.deserialize(json.serialize(serializeDerived(derive(testing.createDoc({}))))) :: json.Value
	) :: json.Object
	assert.eq(json.asObject(parsed.status) ~= nil, true)
	assert.eq(json.asObject(parsed.flow) ~= nil, true)
	assert.eq(json.asObject(parsed.leverage) ~= nil, true)
	assert.eq(json.asObject(parsed.upstream) ~= nil, true)
	assert.eq(json.asObject(parsed.rarity) ~= nil, true)
	assert.eq(json.asObject(parsed.groups) ~= nil, true)
	assert.eq(json.asObject(parsed.pulls) ~= nil, true)
end)

test.case("serializeDerived keys values by item id and sends group counts", function(assert)
	local doc = testing.createDoc(
		{ testing.group("g", "Group"), testing.task("a", "A", "todo", "g"), testing.task("b", "B", "todo") },
		{ { "a", "b" } }
	)
	local parsed =
		json.asObject(json.deserialize(json.serialize(serializeDerived(derive(doc)))) :: json.Value) :: json.Object
	local status = json.asObject(parsed.status) :: json.Object
	local groups = json.asObject(parsed.groups) :: json.Object
	local stats = json.asObject(groups.g) :: json.Object
	assert.eq(status.a, "ready")
	assert.eq(status.b, "blocked")
	local rarity = json.asObject(parsed.rarity) :: json.Object
	assert.eq(rarity.a, "common")
	assert.eq(rarity.b, "common")
	assert.eq(stats.total, 1)
	assert.eq(stats.ready, 1)
	assert.eq(stats.outside, 1)
end)

test.case("serializeDerived sends snoozed pull request facts with when each snooze ends", function(assert)
	local details = json.object({
		state = "OPEN",
		checks = "FAILURE",
		checkCounts = json.object({ total = 2, finished = 2, failed = 1 }),
		failedChecks = { json.object({ name = "docs" }) },
	})
	local ref = json.object({ source = "github", kind = "pull", key = "vocksel/orion#12", details = details })
	local doc = testing.createDoc({ testing.task("a", "A", "review", nil, json.object({ refs = { ref } })) })
	table.insert(doc.settings.checkSnoozes, {
		repo = "vocksel/orion",
		name = "docs",
		untilTime = "2026-10-13T13:00:00Z",
		at = "2026-10-13T00:00:00Z",
		passed = {},
	})

	local serialized = serializeDerived(derive(doc, "2026-10-13T12:00:00Z"))
	local parsed = json.asObject(json.deserialize(json.serialize(serialized)) :: json.Value) :: json.Object
	local pulls = json.asObject(parsed.pulls) :: json.Object
	local facts = json.asObject(pulls.a) :: json.Object
	local snoozed = json.asArray(facts.snoozed) :: json.Array
	local job = json.asObject(snoozed[1]) :: json.Object

	assert.eq(facts.readiness, "passing")
	assert.eq((json.asObject(facts.checks) :: json.Object).state, "passing")
	assert.eq(facts.wakesAt, "2026-10-13T13:00:00Z")
	assert.eq(job.name, "docs")
	assert.eq(job["until"], "2026-10-13T13:00:00Z")
end)
