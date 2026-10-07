local test = require("@std/test")

local graph = require("@root/graph")
local testing = require("@root/testing")

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

test.case("addItem names pull requests after the repository and number", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), task("x", "X", "todo", "g") })
	local item = graph.addItem(doc, "Ship it", { group = "g", repo = "flipbook", pr = 700 })
	assert.eq(item.id, "flipbook-700")
	assert.eq(item.data.itemKind, "pr")
	assert.eq(item.parentId, "g")
	assert.eq(item.position.x > 0, true)
	assert.eq(graph.addItem(doc, "Ship it", {}).id, "ship-it")
	assert.eq(graph.addItem(doc, "Ship it", {}).id, "ship-it-2")
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

test.case("makeGroup and ungroup keep items in place", function(assert)
	local a = task("a", "A", "todo")
	a.position = { x = 100, y = 50 }
	local doc = testing.createDoc({ a, task("b", "B", "todo") })
	local group = graph.makeGroup(doc, "Pair", { "a", "b" })
	assert.eq(a.parentId, group.id)
	assert.eq(group.position.x + a.position.x, 100)
	graph.ungroup(doc, group.id)
	assert.eq(a.parentId, nil)
	assert.eq(a.position.x, 100)
	assert.eq(a.position.y, 50)
end)

test.case("move drops groups it leaves empty and refuses cycles", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), testing.group("h", "H"), task("a", "A", "todo", "g") })
	graph.move(doc, "a", "h")
	assert.eq(graph.find(doc, "g"), nil)
	assert.throws(function()
		graph.move(doc, "h", "h")
	end)
end)
