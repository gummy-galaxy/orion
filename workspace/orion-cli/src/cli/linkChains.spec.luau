local json = require("@std/json")
local test = require("@std/test")

local loadDoc = require("@root/store/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

local function report(output: string): json.Object
	return json.asObject(json.deserialize(output) :: json.Value) :: json.Object
end

local function chainDir(name: string): string
	local dir = testing.directory(name)
	writeDoc(
		dir,
		testing.createDoc({
			testing.task("a", "A", "todo"),
			testing.task("b", "B", "todo"),
			testing.task("c", "C", "todo"),
			testing.task("d", "D", "todo"),
		})
	)
	return dir
end

test.case("link keeps two-item output and writes a chain in one revision", function(assert)
	local dir = chainDir("link-chain")
	assert.eq(testing.run(dir, { "link", "create", "a", "b" }), "b now waits on a")
	local preview = report(testing.run(dir, { "link", "create", "b", "c", "d", "--dry-run", "--json" }))
	assert.eq(preview.action, "link")
	assert.eq(preview.baseRevision, 1)
	assert.eq(preview.revision, 1)
	assert.eq(#(json.asArray(preview.links) :: json.Array), 2)
	assert.eq(#loadDoc(dir).links, 1)
	assert.strContains(
		testing.run(dir, { "link", "create", "b", "c", "d", "--if-revision", "1" }),
		"Linked 2 pairs at revision 1 → 2"
	)
	local doc = loadDoc(dir)
	assert.eq(doc.revision, 2)
	assert.eq(#doc.links, 3)
	assert.eq(doc.links[3].to, "d")
end)

test.case("invalid link chain and stale revision leave every edge untouched", function(assert)
	local dir = chainDir("link-refusal")
	assert.throwsWith("an item can't link to itself", function()
		testing.run(dir, { "link", "create", "a", "b", "b" })
	end)
	assert.throwsWith('no item or group with id "missing"', function()
		testing.run(dir, { "link", "create", "a", "b", "missing" })
	end)
	assert.throwsWith("revision changed: expected 2, current 0", function()
		testing.run(dir, { "link", "create", "a", "b", "--if-revision", "2" })
	end)
	assert.eq(#loadDoc(dir).links, 0)
	assert.eq(loadDoc(dir).revision, 0)
end)

test.case("link reuses an existing pair without duplicating it", function(assert)
	local dir = chainDir("link-existing")
	testing.run(dir, { "link", "create", "a", "b" })
	local applied = report(testing.run(dir, { "link", "create", "a", "b", "c", "--related", "--json" }))
	assert.eq(applied.revision, 2)
	local doc = loadDoc(dir)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].kind, "related")
	assert.eq(doc.links[2].kind, "related")
end)

test.case("insert previews and preserves the replaced link kind", function(assert)
	local dir = chainDir("insert-related")
	testing.run(dir, { "link", "create", "a", "c", "--related" })
	local preview = report(testing.run(dir, { "link", "insert", "b", "--between", "a", "c", "--dry-run", "--json" }))
	assert.eq(preview.action, "insert")
	assert.eq(preview.baseRevision, 1)
	assert.eq(preview.revision, 1)
	assert.eq(#loadDoc(dir).links, 1)
	assert.strContains(
		testing.run(dir, { "link", "insert", "b", "--between", "a", "c", "--if-revision", "1" }),
		"Inserted b between a and c at revision 1 → 2"
	)
	local doc = loadDoc(dir)
	assert.eq(doc.revision, 2)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].from, "a")
	assert.eq(doc.links[1].to, "b")
	assert.eq(doc.links[1].kind, "related")
	assert.eq(doc.links[2].from, "b")
	assert.eq(doc.links[2].to, "c")
	assert.eq(doc.links[2].kind, "related")
end)

test.case("insert refuses absent and self links without writing", function(assert)
	local dir = chainDir("insert-refusal")
	assert.throwsWith('no link from "a" to "c"', function()
		testing.run(dir, { "link", "insert", "b", "--between", "a", "c" })
	end)
	testing.run(dir, { "link", "create", "a", "c" })
	assert.throwsWith("an item can't link to itself", function()
		testing.run(dir, { "link", "insert", "a", "--between", "a", "c" })
	end)
	assert.eq(loadDoc(dir).revision, 1)
	assert.eq(#loadDoc(dir).links, 1)
end)

test.case("remove reconnects cards and previews batch selections", function(assert)
	local dir = chainDir("remove-reconnect")
	testing.run(dir, { "link", "create", "a", "b", "c", "d" })
	local preview = report(testing.run(dir, { "node", "remove", "b", "c", "--reconnect", "--dry-run", "--json" }))
	assert.eq(preview.action, "remove")
	assert.eq(preview.baseRevision, 1)
	assert.eq(preview.revision, 1)
	assert.eq(#(json.asArray(preview.items) :: json.Array), 2)
	assert.eq(#loadDoc(dir).nodes, 4)
	assert.strContains(
		testing.run(dir, { "node", "remove", "b", "c", "--reconnect", "--if-revision", "1" }),
		"Removed 2 items at revision 1 → 2"
	)
	local doc = loadDoc(dir)
	assert.eq(doc.revision, 2)
	assert.eq(#doc.nodes, 2)
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].from, "a")
	assert.eq(doc.links[1].to, "d")
end)

test.case("remove reconnect refuses a branching card before any target is removed", function(assert)
	local dir = chainDir("remove-branch")
	testing.run(dir, { "link", "create", "a", "b", "c" })
	testing.run(dir, { "link", "create", "d", "b" })
	assert.throwsWith('"b" needs at most one incoming and one outgoing link to reconnect', function()
		testing.run(dir, { "node", "remove", "c", "b", "--reconnect" })
	end)
	assert.throwsWith('"b" needs at most one incoming and one outgoing link to reconnect', function()
		testing.run(dir, { "node", "remove", "--where", [[label = "B"]], "--reconnect" })
	end)
	local doc = loadDoc(dir)
	assert.eq(doc.revision, 2)
	assert.eq(#doc.nodes, 4)
	assert.eq(#doc.links, 3)
end)

test.case("remove without reconnect keeps the original card behavior", function(assert)
	local dir = chainDir("remove-plain")
	testing.run(dir, { "link", "create", "a", "b", "c" })
	assert.eq(testing.run(dir, { "node", "remove", "b" }), "Removed b")
	assert.eq(#loadDoc(dir).links, 0)
end)
