local json = require("@std/json")
local test = require("@std/test")

local mentions = require("@root/mentions")
local testing = require("@root/testing")

local CONTEXT: mentions.Context = { owner = "flipbook-labs", name = "flipbook" }

local function fixture()
	return testing.doc({
		testing.task("base", "Base", "todo", nil, { repo = "flipbook", pr = 1 }),
		testing.task("child", "Child", "todo", nil, { repo = "flipbook", pr = 2 }),
		testing.task("other", "Other", "todo", nil, { repo = "flipbook", pr = 3 }),
		testing.task("ticket", "Ticket", "todo", nil, { jira = json.object({ key = "ABC-7" }) }),
	})
end

test.case("explicit phrases make blocking links in the direction they read", function(assert)
	local doc = fixture()
	local child = doc.nodes[2]
	local linked = mentions.link(doc, child, "Stacked on: #1\nBlocks: flipbook-labs/flipbook#3", CONTEXT)
	assert.eq(#linked, 2)
	assert.eq(doc.links[1].from, "base")
	assert.eq(doc.links[1].to, "child")
	assert.eq(doc.links[1].kind, "blocks")
	assert.eq(doc.links[1].origin, "mention")
	assert.eq(doc.links[2].from, "child")
	assert.eq(doc.links[2].to, "other")
	assert.eq(doc.links[2].kind, "blocks")
end)

test.case("plain mentions make related links, even later on a line with a phrase", function(assert)
	local doc = fixture()
	local child = doc.nodes[2]
	mentions.link(doc, child, "Depends on #1 and then see ABC-7 for context", CONTEXT)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].kind, "blocks")
	assert.eq(doc.links[2].from, "ticket")
	assert.eq(doc.links[2].kind, "related")
end)

test.case("a list after a phrase stays blocking, and URLs resolve", function(assert)
	local doc = fixture()
	local other = doc.nodes[3]
	mentions.link(doc, other, "Blocked by #1, https://github.com/flipbook-labs/flipbook/pull/2 and ABC-7", CONTEXT)
	assert.eq(#doc.links, 3)
	for _, link in doc.links do
		assert.eq(link.kind, "blocks")
		assert.eq(link.to, "other")
	end
end)

test.case("existing links stay, but a blocking mention upgrades a related one it made", function(assert)
	local doc = fixture()
	local child = doc.nodes[2]
	doc.links = { { id = "manual", from = "child", to = "other", kind = "related" } }
	mentions.link(doc, child, "See #1 and #3", CONTEXT)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].id, "manual")
	assert.eq(doc.links[2].kind, "related")
	mentions.link(doc, child, "Stacked on #1, see #3", CONTEXT)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[2].from, "base")
	assert.eq(doc.links[2].kind, "blocks")
	assert.eq(doc.links[1].kind, "related")
end)

test.case("unknown references, self-references, and bare numbers without a repository link nothing", function(assert)
	local doc = fixture()
	local child = doc.nodes[2]
	assert.eq(#mentions.link(doc, child, "Stacked on #2, see #99 and XYZ-1", CONTEXT), 0)
	assert.eq(#mentions.link(doc, child, "Stacked on #1", nil), 0)
	assert.eq(#doc.links, 0)
end)

test.case("ownKey prefers the title and falls back to the branch", function(assert)
	assert.eq(mentions.ownKey("#flagged ABC-7 Add it", "agent/xyz-1-thing"), "ABC-7")
	assert.eq(mentions.ownKey("Add it", "abc-12-thing"), "ABC-12")
	assert.eq(mentions.ownKey("Add it", "agent/thing"), nil)
end)
