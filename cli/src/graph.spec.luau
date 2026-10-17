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
	assert.throwsWith("kind must be one of step, gate, component", function()
		graph.setFields(doc, item.id, { kind = "milestone" })
	end)
end)

test.case("components have no status, pass blocking through, and never count as work", function(assert)
	local component = task("api", "API server", "todo", "g", { itemKind = "component" })
	local doc = testing.createDoc(
		{ testing.group("g", "System"), task("a", "A", "active", "g"), component, task("b", "B", "todo", "g") },
		{ { "a", "api" }, { "api", "b" } }
	)
	local derived = graph.derive(doc)
	assert.eq(derived.status.api, nil)
	assert.eq(derived.status.b, "blocked")
	assert.eq(derived.leverage.a, 1)
	assert.eq(derived.leverage.api, nil)
	assert.eq(derived.flow.api, "still")
	assert.eq(derived.upstream.b, 1)
	assert.eq(derived.rarity.api, nil)
	assert.eq(derived.groups.g.components, 1)
	assert.eq(graph.countProgress(derived, "g").total, 2)
end)

test.case("a component keeps its kind when its repository changes, and step turns it back into work", function(assert)
	local doc = testing.createDoc({})
	local item = graph.addItem(doc, "Desktop shell", { kind = "component", repo = "vocksel/orion" })
	assert.eq(item.data.itemKind, "component")
	graph.setFields(doc, item.id, { repo = "" })
	assert.eq(item.data.itemKind, "component")
	graph.setFields(doc, item.id, { kind = "step" })
	assert.eq(item.data.itemKind, "step")
end)

test.case("a shape makes a component, and components and groups take a color", function(assert)
	local doc = testing.createDoc({ testing.group("g", "System") })
	local item = graph.addItem(doc, "orion.json", { shape = "store", color = "amber" })
	assert.eq(item.data.itemKind, "component")
	assert.eq(item.data.shape, "store")
	assert.eq(item.data.color, "amber")

	graph.setFields(doc, item.id, { shape = "", color = "" })
	assert.eq(item.data.shape, nil)
	assert.eq(item.data.color, nil)

	local step = graph.addItem(doc, "Write the docs", {})
	graph.setFields(doc, step.id, { shape = "process" })
	assert.eq(step.data.itemKind, "component")
	graph.setFields(doc, step.id, { kind = "step" })
	assert.eq(step.data.shape, nil)

	graph.setFields(doc, "g", { color = "teal" })
	assert.eq(graph.get(doc, "g").data.color, "teal")
	assert.throwsWith("only components and groups take a color", function()
		graph.setFields(doc, step.id, { color = "rose" })
	end)
	assert.throwsWith("shape must be one of service, store, actor, external, interface, process, queue", function()
		graph.addItem(doc, "Blob", { shape = "blob" })
	end)
end)

test.case("link sets, keeps, and clears a label, and insertBetween keeps it on the first half", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo"), task("n", "N", "todo") })
	local link = graph.link(doc, "a", "b", "blocks", "  HTTP  ")
	assert.eq(link.label, "HTTP")
	graph.link(doc, "a", "b", "related")
	assert.eq(link.label, "HTTP")
	assert.eq(link.kind, "related")

	graph.insertBetween(doc, "n", "a", "b")
	assert.eq(doc.links[1].label, "HTTP")
	assert.eq(doc.links[2].label, nil)

	graph.link(doc, "a", "n", "related", "")
	assert.eq(doc.links[1].label, nil)
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
	assert.eq(derived.groups.inner, { total = 1, done = 0, ready = 1, blocked = 0, outside = 1, components = 0 })
	assert.eq(derived.groups.outer, { total = 2, done = 1, ready = 1, blocked = 0, outside = 1, components = 0 })
	assert.eq(graph.countProgress(derived, "outer"), { total = 2, done = 1, ready = 1, components = 0 })
	assert.eq(graph.countProgress(derived, "missing"), { total = 0, done = 0, ready = 0, components = 0 })
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
	assert.eq(derived.groups.g, { total = 2, done = 1, ready = 1, blocked = 0, outside = 0, components = 0 })
	assert.eq(graph.countProgress(derived, "g"), { total = 2, done = 1, ready = 1, components = 0 })
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

test.case("addItem cuts long ids at a word boundary and suffixes collisions", function(assert)
	local doc = testing.createDoc({})
	local label = "Pick the next slider family piece to build"
	assert.eq(graph.addItem(doc, label, {}).id, "pick-the-next-slider-family")
	assert.eq(graph.addItem(doc, label, {}).id, "pick-the-next-slider-family-2")
end)

test.case("setFields keeps an item's id when its label changes", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group") })
	local item = graph.addItem(doc, "Ship it", {})
	graph.setFields(doc, item.id, { label = "Ship the release" })
	graph.setFields(doc, "g", { label = "Release work" })
	assert.eq(item.id, "ship-it")
	assert.eq(graph.get(doc, "ship-it").data.label, "Ship the release")
	assert.eq(graph.get(doc, "g").data.label, "Release work")
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

test.case("makeGroup marks the new group for the app to tidy", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") })
	local group = graph.makeGroup(doc, "Pair", { "a", "b" })
	assert.eq(group.data.layout, "refit")
end)

test.case("move marks the group it moves into, and ungroup marks the group that takes its items", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		task("x", "X", "todo", "inner"),
		testing.group("other", "Other"),
		task("y", "Y", "todo"),
	})
	graph.move(doc, "y", "other")
	assert.eq(graph.get(doc, "other").data.layout, "refit")
	graph.ungroup(doc, "inner")
	assert.eq(graph.get(doc, "x").parentId, "outer")
	assert.eq(graph.get(doc, "outer").data.layout, "refit")
end)

test.case("tidying a group the CLI joins keeps a pending marker and skips custom groups", function(assert)
	local pending = testing.group("pending", "Pending")
	pending.data.layout = "pending"
	local custom = testing.group("custom", "Custom")
	custom.data.arrange = "custom"
	local doc = testing.createDoc({
		pending,
		custom,
		task("a", "A", "todo"),
		task("b", "B", "todo"),
		task("c", "C", "todo", "custom"),
	})
	graph.move(doc, "a", "pending")
	assert.eq(pending.data.layout, "pending")
	graph.move(doc, "b", "custom")
	assert.eq(custom.data.layout, nil)
end)

test.case("move drops groups it leaves empty and refuses cycles", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), testing.group("h", "H"), task("a", "A", "todo", "g") })
	graph.move(doc, "a", "h")
	assert.eq(graph.find(doc, "g"), nil)
	assert.throws(function()
		graph.move(doc, "h", "h")
	end)
end)

test.case("a group takes a cover and background, and an empty value clears them", function(assert)
	local doc = testing.createDoc({ testing.group("ws", "Workspace", nil), task("a", "A", "todo") })
	graph.setFields(doc, "ws", { cover = "image-logo.png", background = "card.background" })
	local group = graph.get(doc, "ws")
	assert.eq(group.data.cover, "image-logo.png")
	assert.eq(group.data.background, "card.background")
	graph.setFields(doc, "ws", { background = "" })
	assert.eq(group.data.background, nil)
	assert.eq(group.data.cover, "image-logo.png")
	graph.setFields(doc, "ws", { cover = "" })
	assert.eq(group.data.cover, nil)
end)

test.case("a group takes a header, and an empty value clears it", function(assert)
	local doc = testing.createDoc({ testing.group("ws", "Workspace", nil) })
	graph.setFields(doc, "ws", { header = "# Sprint 14" })
	assert.eq(graph.get(doc, "ws").data.header, "# Sprint 14")
	graph.setFields(doc, "ws", { header = "" })
	assert.eq(graph.get(doc, "ws").data.header, nil)
end)

test.case("adding a header moves the group's top edge up and keeps its cards where they are", function(assert)
	local group = testing.group("ws", "Workspace", nil)
	group.position = { x = 100, y = 300 }
	group.height = 300
	local doc = testing.createDoc({ group, task("a", "A", "todo", "ws") })
	doc.nodes[2].position = { x = 32, y = 78 }
	graph.setFields(doc, "ws", { header = "# Sprint 14" })
	assert.eq(graph.get(doc, "ws").position.y, 300 - 112)
	assert.eq(graph.get(doc, "ws").height, 300 + 112)
	assert.eq(graph.get(doc, "a").position.y, 78 + 112)
	graph.setFields(doc, "ws", { header = "" })
	assert.eq(graph.get(doc, "ws").position.y, 300)
	assert.eq(graph.get(doc, "ws").height, 300)
	assert.eq(graph.get(doc, "a").position.y, 78)
end)

test.case("a card added to a group with a header starts below the header band", function(assert)
	local doc = testing.createDoc({ testing.group("ws", "Workspace", nil) })
	graph.setFields(doc, "ws", { header = "# Sprint 14" })
	local added = graph.addItem(doc, "Next", { group = "ws" })
	assert.eq(added.position.y, 78 + 112)
end)

test.case("an item refuses a cover or background or header, and a group refuses a bad one", function(assert)
	local doc = testing.createDoc({ testing.group("ws", "Workspace", nil), task("a", "A", "todo") })
	assert.throwsWith('"a" is an item; only groups take a cover, background, or header', function()
		graph.setFields(doc, "a", { cover = "image-logo.png" })
	end)
	assert.throwsWith('"a" is an item; only groups take a cover, background, or header', function()
		graph.setFields(doc, "a", { background = "#fff" })
	end)
	assert.throwsWith('"a" is an item; only groups take a cover, background, or header', function()
		graph.setFields(doc, "a", { header = "# Hi" })
	end)
	assert.throws(function()
		graph.setFields(doc, "ws", { cover = "../orion.json" })
	end)
	assert.throws(function()
		graph.setFields(doc, "ws", { background = "red" })
	end)
	assert.eq(graph.get(doc, "ws").data.cover, nil)
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

test.case("setFields snoozes and wakes a work item, and refuses a time that isn't UTC", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), task("a", "A", "todo") })
	graph.setFields(doc, "a", { snoozedUntil = "2026-10-12T17:00:00Z" })
	assert.eq(graph.get(doc, "a").data.snoozedUntil, "2026-10-12T17:00:00Z")
	graph.setFields(doc, "a", { snoozedUntil = "" })
	assert.eq(graph.get(doc, "a").data.snoozedUntil, nil)
	assert.throws(function()
		graph.setFields(doc, "a", { snoozedUntil = "next week" })
	end)
	assert.throws(function()
		graph.setFields(doc, "g", { snoozedUntil = "2026-10-12T17:00:00Z" })
	end)
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

test.case("create makes an empty group at the top or inside another group", function(assert)
	local doc = testing.createDoc({ testing.group("ws", "Workspace"), task("a", "A", "todo") })
	local weekly = graph.createGroup(doc, "Week 1")
	assert.eq(weekly.id, "week-1")
	assert.eq(weekly.parentId, nil)
	local inner = graph.createGroup(doc, "Monday", "ws")
	assert.eq(inner.parentId, "ws")
	assert.eq(graph.isGroup(inner), true)
	assert.eq(graph.countProgress(graph.derive(doc), "week-1").total, 0)
	assert.throwsWith('no item or group with id "missing"', function()
		graph.createGroup(doc, "Nowhere", "missing")
	end)
	assert.throwsWith("a group needs a name", function()
		graph.createGroup(doc, "")
	end)
end)

test.case("an empty group made on purpose survives moves elsewhere, and emptied groups still go", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "G"),
		testing.group("h", "H"),
		testing.group("kept", "Kept"),
		task("a", "A", "todo", "g"),
		task("b", "B", "todo"),
	})
	graph.move(doc, "a", "h")
	assert.eq(graph.find(doc, "g"), nil)
	assert.eq(graph.find(doc, "kept") ~= nil, true)
end)

test.case("removing the last item of a nested group also drops the group above it when it empties", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		task("a", "A", "todo", "inner"),
		testing.group("spare", "Spare"),
	})
	graph.remove(doc, "a")
	assert.eq(graph.find(doc, "inner"), nil)
	assert.eq(graph.find(doc, "outer"), nil)
	assert.eq(graph.find(doc, "spare") ~= nil, true)
end)
