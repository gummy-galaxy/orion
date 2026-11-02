local test = require("@std/test")

local countProgress = require("@root/canvas/items/countProgress")
local derive = require("@root/canvas/derive")
local snooze = require("@root/canvas/items/snooze")
local testing = require("@root/testing")
local types = require("@root/types")

local task = testing.task

test.case("derive marks work waiting on open items as blocked and the rest ready", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("b", "B", "todo"), task("c", "C", "done") },
		{ { "a", "b" }, { "c", "a" } }
	)
	local derived = derive(doc)
	assert.eq(derived.status.a, "ready")
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.leverage.a, 1)
end)

test.case("derive passes blocking through notes without counting them", function(assert)
	local note = task("n", "Remember", "todo", nil, { type = "note" })
	local doc = testing.createDoc(
		{ task("a", "A", "active"), note, task("b", "B", "todo") },
		{ { "a", "n" }, { "n", "b" } }
	)
	local derived = derive(doc)
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.leverage.a, 1)
	assert.eq(derived.leverage.n, nil)
end)

test.case("derive finishes a gate once everything it waits on is done", function(assert)
	local gate = task("g", "Ready to ship", "todo", nil, { type = "gate" })
	local doc = testing.createDoc(
		{ task("a", "A", "done"), task("b", "B", "active"), gate, task("c", "C", "todo") },
		{ { "a", "g" }, { "b", "g" }, { "g", "c" } }
	)
	local derived = derive(doc)
	assert.eq(derived.status.g, "blocked")
	assert.eq(derived.status.c, "blocked")
	assert.eq(derived.leverage.b, 2)
	doc.nodes[2].data.status = "done"
	derived = derive(doc)
	assert.eq(derived.status.g, "done")
	assert.eq(derived.status.c, "ready")

	local lone = testing.createDoc({ task("g", "Lone gate", "todo", nil, { type = "gate" }) })
	assert.eq(derive(lone).status.g, "ready")
end)

test.case("components have no status, pass blocking through, and never count as work", function(assert)
	local component = task("api", "API server", "todo", "g", { type = "component" })
	local doc = testing.createDoc(
		{ testing.group("g", "System"), task("a", "A", "active", "g"), component, task("b", "B", "todo", "g") },
		{ { "a", "api" }, { "api", "b" } }
	)
	local derived = derive(doc)
	assert.eq(derived.status.api, nil)
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.leverage.a, 1)
	assert.eq(derived.leverage.api, nil)
	assert.eq(derived.flow.api, "still")
	assert.eq(derived.upstream.b, 1)
	assert.eq(derived.rarity.api, nil)
	assert.eq(derived.groups.g.components, 1)
	assert.eq(countProgress(derived, "g").total, 2)
end)

test.case("derive keeps hand-set blocked and deferred, and skips deferred work in leverage", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("b", "B", "deferred"), task("c", "C", "blocked") },
		{ { "a", "b" } }
	)
	local derived = derive(doc)
	assert.eq(derived.status.b, "deferred")
	assert.eq(derived.status.c, "blocked")
	assert.eq(derived.leverage.a, 0)
end)

-- A chain of `count` open cards, each waiting on the one before it.
local function chain(count: number): ({ string }, types.Doc)
	local ids: { string } = {}
	local nodes: { types.Item } = {}
	local links: { { string } } = {}

	for index = 1, count do
		local id = `n{index}`
		table.insert(ids, id)
		table.insert(nodes, task(id, id, "todo"))

		if index > 1 then
			table.insert(links, { ids[index - 1], id })
		end
	end

	return ids, testing.createDoc(nodes, links)
end

test.case("derive holds flow after work that waits and moves out of work that can start", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("b", "B", "todo"), task("c", "C", "todo") },
		{ { "a", "b" }, { "b", "c" } }
	)
	local derived = derive(doc)
	assert.eq(derived.flow.a, "live")
	assert.eq(derived.flow.b, "held")
	assert.eq(derived.flow.c, "held")
end)

test.case("derive holds flow after blocked or deferred work and keeps it moving after done work", function(assert)
	local doc = testing.createDoc({
		task("blocked", "", "blocked"),
		task("deferred", "", "deferred"),
		task("done", "", "done"),
	})
	local derived = derive(doc)
	assert.eq(derived.flow.blocked, "held")
	assert.eq(derived.flow.deferred, "held")
	assert.eq(derived.flow.done, "live")
end)

test.case("derive passes flow through notes", function(assert)
	local doc = testing.createDoc({
		task("ready", "", "todo"),
		task("waiting", "", "active"),
		task("n1", "", "todo", nil, { type = "note" }),
		task("n2", "", "todo", nil, { type = "note" }),
		task("x", "", "todo"),
		task("y", "", "todo"),
	}, { { "ready", "n1" }, { "n1", "x" }, { "ready", "waiting" }, { "waiting", "n2" }, { "n2", "y" } })
	local derived = derive(doc)
	assert.eq(derived.flow.n1, "live")
	assert.eq(derived.flow.n2, "held")
end)

test.case("derive counts a chain of upstream work, including completed work and gates", function(assert)
	local gate = task("gate", "Gate", "todo", nil, { type = "gate" })
	local doc = testing.createDoc(
		{ task("a", "A", "done"), task("b", "B", "todo"), gate },
		{ { "a", "b" }, { "b", "gate" } }
	)
	local derived = derive(doc)
	assert.eq(derived.upstream.a, 0)
	assert.eq(derived.upstream.b, 1)
	assert.eq(derived.upstream.gate, 2)
end)

test.case("derive counts a shared ancestor once in a diamond", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("b", "B", "todo"), task("c", "C", "todo"), task("d", "D", "todo") },
		{ { "a", "b" }, { "a", "c" }, { "b", "d" }, { "c", "d" } }
	)
	assert.eq(derive(doc).upstream.d, 3)
end)

test.case("derive passes upstream through notes without counting them", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("note", "", "todo", nil, { type = "note" }), task("b", "B", "todo") },
		{ { "a", "note" }, { "note", "b" } }
	)
	assert.eq(derive(doc).upstream.b, 1)
end)

test.case("derive ignores related links when counting upstream work", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") }, { { "a", "b", "related" } })
	assert.eq(derive(doc).upstream.b, 0)
end)

test.case("derive terminates a cycle and leaves the card itself out of its upstream", function(assert)
	local doc = testing.createDoc({
		task("a", "A", "todo"),
		task("b", "B", "todo"),
		task("note", "", "todo", nil, { type = "note" }),
		task("c", "C", "todo"),
	}, { { "a", "b" }, { "b", "note" }, { "note", "a" }, { "b", "c" } })
	local derived = derive(doc)
	assert.eq(derived.upstream.a, 1)
	assert.eq(derived.upstream.b, 1)
	assert.eq(derived.upstream.c, 2)
end)

test.case("derive gives rarity from upstream work and leaves notes without one", function(assert)
	local ids, doc = chain(16)
	local derived = derive(doc)
	assert.eq(derived.rarity[ids[1]], "common")
	assert.eq(derived.rarity[ids[4]], "common")
	assert.eq(derived.rarity[ids[5]], "uncommon")
	assert.eq(derived.rarity[ids[9]], "rare")
	assert.eq(derived.rarity[ids[15]], "mythic")
	assert.eq(derived.rarity[ids[16]], "mythic")
	assert.eq(derived.upstream[ids[16]], 15)

	local note = derive(testing.createDoc({ task("n", "", "todo", nil, { type = "note" }) }))
	assert.eq(note.rarity.n, nil)
end)

test.case("derive counts each group's progress and the work it reaches outside itself", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		task("a", "A", "todo", "inner"),
		task("b", "B", "done", "outer"),
		task("c", "C", "todo"),
		task("note", "", "todo", "outer", { type = "note" }),
	}, { { "a", "c" } })
	local derived = derive(doc)
	assert.eq(derived.groups.inner, { total = 1, done = 0, ready = 1, blocked = 0, outside = 1, components = 0 })
	assert.eq(derived.groups.outer, { total = 2, done = 1, ready = 1, blocked = 0, outside = 1, components = 0 })
	assert.eq(countProgress(derived, "outer"), { total = 2, done = 1, ready = 1, components = 0 })
	assert.eq(countProgress(derived, "missing"), { total = 0, done = 0, ready = 0, components = 0 })
end)

test.case("derive leaves deferred work and notes out of a group's total", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "Group"),
		task("a", "A", "done", "g"),
		task("b", "B", "todo", "g"),
		task("c", "C", "deferred", "g"),
		task("n", "Remember", "todo", "g", { type = "note" }),
	})
	local derived = derive(doc)
	assert.eq(derived.groups.g, { total = 2, done = 1, ready = 1, blocked = 0, outside = 0, components = 0 })
	assert.eq(countProgress(derived, "g"), { total = 2, done = 1, ready = 1, components = 0 })
end)

test.case("derive hides a snoozed card from ready and leverage, but not from blocking", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") }, { { "a", "b" } })
	snooze(doc, "a", "2026-10-12T17:00:00Z")
	local derived = derive(doc, "2026-10-04T00:00:00Z")
	assert.eq(derived.status.a, "ready")
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.snoozed.a, "2026-10-12T17:00:00Z")
	assert.eq(derived.leverage.a, nil)
	assert.eq(derived.snoozed.b, nil)
end)

test.case("derive lets a snoozed card come back once its time has passed", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), task("a", "A", "todo", "g") })
	snooze(doc, "a", "2026-10-12T17:00:00Z")
	assert.eq(derive(doc, "2026-10-12T16:59:59Z").snoozed.a, "2026-10-12T17:00:00Z")
	local woken = derive(doc, "2026-10-12T17:00:00Z")
	assert.eq(woken.snoozed.a, nil)
	assert.eq(woken.status.a, "ready")
	assert.eq(woken.groups.g.ready, 1)
end)

test.case("derive leaves a snoozed card out of its group's ready count", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), task("a", "A", "todo", "g"), task("b", "B", "todo", "g") })
	snooze(doc, "a", "2026-10-12T17:00:00Z")
	local stats = derive(doc, "2026-10-04T00:00:00Z").groups.g
	assert.eq(stats.total, 2)
	assert.eq(stats.ready, 1)
end)

test.case("derive counts progress across the whole canvas the way it does for a group", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "G"),
		task("a", "A", "todo", "g"),
		task("b", "B", "done"),
		task("c", "C", "todo"),
		task("d", "D", "deferred"),
		task("n", "Note", "todo", nil, { type = "note" }),
	}, { { "a", "c" } })
	snooze(doc, "a", "2026-10-12T17:00:00Z")
	local canvas = derive(doc, "2026-10-04T00:00:00Z").canvas
	assert.eq(canvas.total, 3)
	assert.eq(canvas.done, 1)
	assert.eq(canvas.ready, 0)
	assert.eq(canvas.blocked, 1)
	assert.eq(canvas.outside, 0)
end)

test.case(
	"derive lists open work where it's your move, leaving out blocked, finished, and snoozed work",
	function(assert)
		local yours = { who = "you" }
		local doc = testing.createDoc({
			task("ready", "Ready", "todo", nil, yours),
			task("active", "Active", "active", nil, yours),
			task("blocked", "Blocked", "todo", nil, yours),
			task("done", "Done", "done", nil, yours),
			task("deferred", "Deferred", "deferred", nil, yours),
			task("snoozed", "Snoozed", "todo", nil, yours),
			task("theirs", "Theirs", "todo", nil, { who = "review" }),
			task("note", "Note", "todo", nil, { type = "note", who = "you" }),
		}, { { "active", "blocked" } })
		snooze(doc, "snoozed", "2026-10-12T17:00:00Z")
		local attention = derive(doc, "2026-10-04T00:00:00Z").attention
		assert.eq(attention, { ready = true, active = true })
	end
)
