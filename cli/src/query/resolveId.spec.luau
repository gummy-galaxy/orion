local json = require("@std/json")
local test = require("@std/test")

local resolveId = require("@root/query/resolveId")
local testing = require("@root/testing")

local function sample()
	return testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, {
			refs = { json.object({ source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" }) },
		}),
		testing.task("pub", "Publish v2.6.0", "todo"),
		testing.task("pub-2", "Publish v2.6.0", "todo"),
		testing.task("draft", "Draft notes", "todo", nil, { note = "Ask about pr:12" }),
	})
end

test.case("a plain id passes through, and selectors resolve to one item", function(assert)
	local doc = sample()
	assert.eq(resolveId(doc, "ci"), "ci")
	assert.eq(resolveId(doc, "missing"), "missing")
	assert.eq(resolveId(doc, `label:"Report release health"`), "ci")
	assert.eq(resolveId(doc, "label:'Report release health'"), "ci")
	assert.eq(resolveId(doc, "label:Draft notes"), "draft")
	assert.eq(resolveId(doc, "ref:flipbook-labs/flipbook#658"), "ci")
	assert.eq(resolveId(doc, "ref:FLIPBOOK-LABS/flipbook#658"), "ci")
	assert.eq(resolveId(doc, "pr:658"), "ci")
	assert.eq(resolveId(doc, "pr:#658"), "ci")
	assert.eq(resolveId(doc, "pr:flipbook-labs/flipbook#658"), "ci")
end)

test.case("an ambiguous or unmatched selector fails instead of picking an item", function(assert)
	local doc = sample()
	assert.throws(function()
		resolveId(doc, `label:"Publish v2.6.0"`)
	end)
	assert.throws(function()
		resolveId(doc, `label:"Nothing like this"`)
	end)
	assert.throws(function()
		resolveId(doc, "label:")
	end)
	assert.throws(function()
		resolveId(doc, "owner:orion")
	end)
end)

test.case("pr selectors match pull refs, not note text", function(assert)
	local doc = sample()
	assert.throws(function()
		resolveId(doc, "pr:12")
	end)
end)
