local test = require("@std/test")

local findRef = require("@root/refs/findRef")
local graph = require("@root/graph")
local testing = require("@root/testing")
local types = require("@root/types")

local task = testing.task

test.case("derive marks work waiting on open items as blocked and the rest ready", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("b", "B", "todo"), task("c", "C", "done") },
		{ { "a", "b" }, { "c", "a" } }
	)
	local derived = graph.derive(doc)
	assert.eq(derived.status.a, "ready")
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.leverage.a, 1)
end)

test.case("derive passes blocking through notes without counting them", function(assert)
	local note = task("n", "Remember", "todo", nil, { itemKind = "note" })
	local doc = testing.createDoc(
		{ task("a", "A", "active"), note, task("b", "B", "todo") },
		{ { "a", "n" }, { "n", "b" } }
	)
	local derived = graph.derive(doc)
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.leverage.a, 1)
	assert.eq(derived.leverage.n, nil)
end)

test.case("derive finishes a gate once everything it waits on is done", function(assert)
	local gate = task("g", "Ready to ship", "todo", nil, { itemKind = "gate" })
	local doc = testing.createDoc(
		{ task("a", "A", "done"), task("b", "B", "active"), gate, task("c", "C", "todo") },
		{ { "a", "g" }, { "b", "g" }, { "g", "c" } }
	)
	local derived = graph.derive(doc)
	assert.eq(derived.status.g, "blocked")
	assert.eq(derived.status.c, "blocked")
	assert.eq(derived.leverage.b, 2)
	doc.nodes[2].data.status = "done"
	derived = graph.derive(doc)
	assert.eq(derived.status.g, "done")
	assert.eq(derived.status.c, "ready")

	local lone = testing.createDoc({ task("g", "Lone gate", "todo", nil, { itemKind = "gate" }) })
	assert.eq(graph.derive(lone).status.g, "ready")
end)

test.case("add and set take a gate kind, and a gate stays one when its repository changes", function(assert)
	local doc = testing.createDoc({})
	local item = graph.addItem(doc, "Closure audit", { kind = "gate" })
	assert.eq(item.data.itemKind, "gate")
	graph.setFields(doc, item.id, { repo = "vocksel/orion" })
	assert.eq(item.data.itemKind, "gate")
	graph.setFields(doc, item.id, { kind = "step" })
	assert.eq(item.data.itemKind, "placeholder")
	assert.throwsWith("kind must be step or gate", function()
		graph.setFields(doc, item.id, { kind = "milestone" })
	end)
end)

test.case("derive keeps hand-set blocked and deferred, and skips deferred work in leverage", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("b", "B", "deferred"), task("c", "C", "blocked") },
		{ { "a", "b" } }
	)
	local derived = graph.derive(doc)
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
	local derived = graph.derive(doc)
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
	local derived = graph.derive(doc)
	assert.eq(derived.flow.blocked, "held")
	assert.eq(derived.flow.deferred, "held")
	assert.eq(derived.flow.done, "live")
end)

test.case("derive passes flow through notes", function(assert)
	local doc = testing.createDoc({
		task("ready", "", "todo"),
		task("waiting", "", "active"),
		task("n1", "", "todo", nil, { itemKind = "note" }),
		task("n2", "", "todo", nil, { itemKind = "note" }),
		task("x", "", "todo"),
		task("y", "", "todo"),
	}, { { "ready", "n1" }, { "n1", "x" }, { "ready", "waiting" }, { "waiting", "n2" }, { "n2", "y" } })
	local derived = graph.derive(doc)
	assert.eq(derived.flow.n1, "live")
	assert.eq(derived.flow.n2, "held")
end)

test.case("derive counts a chain of upstream work, including completed work and gates", function(assert)
	local gate = task("gate", "Gate", "todo", nil, { itemKind = "gate" })
	local doc = testing.createDoc(
		{ task("a", "A", "done"), task("b", "B", "todo"), gate },
		{ { "a", "b" }, { "b", "gate" } }
	)
	local derived = graph.derive(doc)
	assert.eq(derived.upstream.a, 0)
	assert.eq(derived.upstream.b, 1)
	assert.eq(derived.upstream.gate, 2)
end)

test.case("derive counts a shared ancestor once in a diamond", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("b", "B", "todo"), task("c", "C", "todo"), task("d", "D", "todo") },
		{ { "a", "b" }, { "a", "c" }, { "b", "d" }, { "c", "d" } }
	)
	assert.eq(graph.derive(doc).upstream.d, 3)
end)

test.case("derive passes upstream through notes without counting them", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("note", "", "todo", nil, { itemKind = "note" }), task("b", "B", "todo") },
		{ { "a", "note" }, { "note", "b" } }
	)
	assert.eq(graph.derive(doc).upstream.b, 1)
end)

test.case("derive ignores related links when counting upstream work", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") }, { { "a", "b", "related" } })
	assert.eq(graph.derive(doc).upstream.b, 0)
end)

test.case("derive terminates a cycle and leaves the card itself out of its upstream", function(assert)
	local doc = testing.createDoc({
		task("a", "A", "todo"),
		task("b", "B", "todo"),
		task("note", "", "todo", nil, { itemKind = "note" }),
		task("c", "C", "todo"),
	}, { { "a", "b" }, { "b", "note" }, { "note", "a" }, { "b", "c" } })
	local derived = graph.derive(doc)
	assert.eq(derived.upstream.a, 1)
	assert.eq(derived.upstream.b, 1)
	assert.eq(derived.upstream.c, 2)
end)

test.case("derive gives rarity from upstream work and leaves notes without one", function(assert)
	local ids, doc = chain(16)
	local derived = graph.derive(doc)
	assert.eq(derived.rarity[ids[1]], "common")
	assert.eq(derived.rarity[ids[4]], "common")
	assert.eq(derived.rarity[ids[5]], "uncommon")
	assert.eq(derived.rarity[ids[9]], "rare")
	assert.eq(derived.rarity[ids[15]], "mythic")
	assert.eq(derived.rarity[ids[16]], "mythic")
	assert.eq(derived.upstream[ids[16]], 15)

	local note = graph.derive(testing.createDoc({ task("n", "", "todo", nil, { itemKind = "note" }) }))
	assert.eq(note.rarity.n, nil)
end)

test.case("derive counts each group's progress and the work it reaches outside itself", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		task("a", "A", "todo", "inner"),
		task("b", "B", "done", "outer"),
		task("c", "C", "todo"),
		task("note", "", "todo", "outer", { itemKind = "note" }),
	}, { { "a", "c" } })
	local derived = graph.derive(doc)
	assert.eq(derived.groups.inner, { total = 1, done = 0, ready = 1, blocked = 0, outside = 1 })
	assert.eq(derived.groups.outer, { total = 2, done = 1, ready = 1, blocked = 0, outside = 1 })
	assert.eq(graph.countProgress(derived, "outer"), { total = 2, done = 1, ready = 1 })
	assert.eq(graph.countProgress(derived, "missing"), { total = 0, done = 0, ready = 0 })
end)

test.case("derive leaves deferred work and notes out of a group's total", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "Group"),
		task("a", "A", "done", "g"),
		task("b", "B", "todo", "g"),
		task("c", "C", "deferred", "g"),
		task("n", "Remember", "todo", "g", { itemKind = "note" }),
	})
	local derived = graph.derive(doc)
	assert.eq(derived.groups.g, { total = 2, done = 1, ready = 1, blocked = 0, outside = 0 })
	assert.eq(graph.countProgress(derived, "g"), { total = 2, done = 1, ready = 1 })
end)

test.case("addItem names pull requests after the repository and number", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), task("x", "X", "todo", "g") })
	local item = graph.addItem(doc, "Ship it", { group = "g", repo = "flipbook-labs/flipbook", pr = 700 })
	assert.eq(item.id, "flipbook-labs-flipbook-700")
	assert.eq(item.data.itemKind, "pr")
	assert.eq(item.parentId, "g")
	assert.eq(item.position.x > 0, true)
	assert.eq(graph.addItem(doc, "Ship it", {}).id, "ship-it")
	assert.eq(graph.addItem(doc, "Ship it", {}).id, "ship-it-2")
end)

test.case("repo and pull fields use full repository names and refs", function(assert)
	local doc = testing.createDoc({})
	assert.throwsWith("repo must be owner/name", function()
		graph.addItem(doc, "Short", { repo = "orion" })
	end)
	assert.throwsWith("pr needs a repository as owner/name", function()
		graph.addItem(doc, "Pull", { pr = 12 })
	end)
	local item = graph.addItem(doc, "Pull", { repo = "vocksel/orion", pr = 12 })
	assert.eq((findRef(item, "pull") :: any).key, "vocksel/orion#12")
	graph.setFields(doc, item.id, { pr = 13 })
	assert.eq((findRef(item, "pull") :: any).key, "vocksel/orion#13")
	assert.eq(findRef(item, "pull", "vocksel/orion#12"), nil)
	graph.setFields(doc, item.id, { repo = "" })
	assert.eq(findRef(item, "pull"), nil)
	assert.eq(item.data.itemKind, "step")
end)

test.case("setFields arranges groups and asks the app to lay them out again", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), task("x", "X", "todo", "g") })
	local group = graph.setFields(doc, "g", { arrange = "custom" })
	assert.eq(group.data.arrange, "custom")
	assert.eq(group.data.layout, nil)
	graph.setFields(doc, "g", { arrange = "auto" })
	assert.eq(group.data.arrange, nil)
	assert.eq(group.data.layout, "refit")
end)

test.case("setFields rejects bad arrangements", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), task("x", "X", "todo", "g") })
	assert.throwsWith("arrange must be one of auto, custom", function()
		graph.setFields(doc, "g", { arrange = "grid" })
	end)
	assert.throwsWith("only groups take an arrangement", function()
		graph.setFields(doc, "x", { arrange = "custom" })
	end)
	assert.eq(doc.nodes[1].data.arrange, nil)
end)

test.case("addItem rejects unknown statuses", function(assert)
	local doc = testing.createDoc({})
	assert.throws(function()
		graph.addItem(doc, "X", { status = "maybe" })
	end)
end)

test.case("addNote splices into an existing link and remove reconnects it", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") }, { { "a", "b" } })
	local note = graph.addNote(doc, "Check the hash", { after = "a", before = "b" })
	assert.eq(#doc.links, 2)
	assert.eq(graph.derive(doc).status.b, "blocked")
	graph.remove(doc, note.id)
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].from, "a")
	assert.eq(doc.links[1].to, "b")
end)

test.case("notes share link insertion and preserve a related link", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") }, { { "a", "b", "related" } })
	local note = graph.addNote(doc, "Check the hash", { after = "a", before = "b" })
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].kind, "related")
	assert.eq(doc.links[2].kind, "related")
	graph.remove(doc, note.id)
	assert.eq(doc.links[1].kind, "related")
end)

test.case("addNote links both sides when the surrounding items are unlinked", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") })
	local note = graph.addNote(doc, "Check the hash", { after = "a", before = "b" })
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].from, "a")
	assert.eq(doc.links[1].to, note.id)
	assert.eq(doc.links[1].kind, "blocks")
	assert.eq(doc.links[2].from, note.id)
	assert.eq(doc.links[2].to, "b")
	assert.eq(doc.links[2].kind, "blocks")
end)

test.case("addNote after the same item finds a free spot for each note", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo") })
	local first = graph.addNote(doc, "First", { after = "a" })
	local second = graph.addNote(doc, "Second", { after = "a" })
	assert.eq(first.position.x, second.position.x)
	assert.eq(second.position.y > first.position.y, true)
end)

test.case("makeGroup and ungroup keep items in place", function(assert)
	local firstTask = task("a", "A", "todo")
	firstTask.position = { x = 100, y = 50 }
	local doc = testing.createDoc({ firstTask, task("b", "B", "todo") })
	local group = graph.makeGroup(doc, "Pair", { "a", "b" })
	assert.eq(firstTask.parentId, group.id)
	assert.eq(group.position.x + firstTask.position.x, 100)
	graph.ungroup(doc, group.id)
	assert.eq(firstTask.parentId, nil)
	assert.eq(firstTask.position.x, 100)
	assert.eq(firstTask.position.y, 50)
end)

test.case("move drops groups it leaves empty and refuses cycles", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), testing.group("h", "H"), task("a", "A", "todo", "g") })
	graph.move(doc, "a", "h")
	assert.eq(graph.find(doc, "g"), nil)
	assert.throws(function()
		graph.move(doc, "h", "h")
	end)
end)

test.case("derive hides a snoozed card from ready and leverage, but not from blocking", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") }, { { "a", "b" } })
	graph.snooze(doc, "a", "2026-10-12T17:00:00Z")
	local derived = graph.derive(doc, "2026-10-04T00:00:00Z")
	assert.eq(derived.status.a, "ready")
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.snoozed.a, "2026-10-12T17:00:00Z")
	assert.eq(derived.leverage.a, nil)
	assert.eq(derived.snoozed.b, nil)
end)

test.case("derive lets a snoozed card come back once its time has passed", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), task("a", "A", "todo", "g") })
	graph.snooze(doc, "a", "2026-10-12T17:00:00Z")
	assert.eq(graph.derive(doc, "2026-10-12T16:59:59Z").snoozed.a, "2026-10-12T17:00:00Z")
	local woken = graph.derive(doc, "2026-10-12T17:00:00Z")
	assert.eq(woken.snoozed.a, nil)
	assert.eq(woken.status.a, "ready")
	assert.eq(woken.groups.g.ready, 1)
end)

test.case("derive leaves a snoozed card out of its group's ready count", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), task("a", "A", "todo", "g"), task("b", "B", "todo", "g") })
	graph.snooze(doc, "a", "2026-10-12T17:00:00Z")
	local stats = graph.derive(doc, "2026-10-04T00:00:00Z").groups.g
	assert.eq(stats.total, 2)
	assert.eq(stats.ready, 1)
end)

test.case("snooze sets and clears a work item's wake time, and refuses groups and notes", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "G"),
		task("a", "A", "todo"),
		task("n", "Note", "todo", nil, { itemKind = "note" }),
	})
	graph.snooze(doc, "a", "2026-10-12T17:00:00Z")
	assert.eq(doc.nodes[2].data.snoozedUntil, "2026-10-12T17:00:00Z")
	graph.snooze(doc, "a", nil)
	assert.eq(doc.nodes[2].data.snoozedUntil, nil)
	assert.throws(function()
		graph.snooze(doc, "g", "2026-10-12T17:00:00Z")
	end)
	assert.throws(function()
		graph.snooze(doc, "n", "2026-10-12T17:00:00Z")
	end)
end)

test.case("markCelebrations flags a card that turns done and clears the flag when it reopens", function(assert)
	local doc = testing.createDoc({ task("a", "A", "active"), task("b", "B", "done") })
	local previous = graph.recordedStatuses(doc)
	doc.nodes[1].data.status = "done"
	graph.markCelebrations(doc, previous)
	assert.eq(doc.nodes[1].data.celebrate, true)
	assert.eq(doc.nodes[2].data.celebrate, nil)

	previous = graph.recordedStatuses(doc)
	doc.nodes[1].data.status = "todo"
	graph.markCelebrations(doc, previous)
	assert.eq(doc.nodes[1].data.celebrate, nil)
end)

test.case("markCelebrations keeps a flag until the card is reopened, and skips new cards and notes", function(assert)
	local doc = testing.createDoc({
		task("a", "A", "done", nil, { celebrate = true }),
		task("created", "Created done", "done"),
		task("n", "Note", "todo", nil, { itemKind = "note" }),
	})
	local previous = graph.recordedStatuses(doc)
	doc.nodes[1].data.label = "Renamed"
	doc.nodes[3].data.status = "done"
	graph.markCelebrations(doc, previous)
	assert.eq(doc.nodes[1].data.celebrate, true)
	assert.eq(doc.nodes[2].data.celebrate, nil)
	assert.eq(doc.nodes[3].data.celebrate, nil)
end)
