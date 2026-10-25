local json = require("@std/json")
local test = require("@std/test")

local getCurrentKey = require("@root/github/getCurrentKey")
local identifyRef = require("@root/github/identifyRef")
local testing = require("@root/testing")
local types = require("@root/types")

type Ref = types.Ref

local function moved(): any
	local doc = testing.createDoc({})
	doc.repositories = json.object({
		["1"] = json.object({ name = "gummy-galaxy/orion", aliases = { "vocksel/orion" } }),
	})
	return doc
end

test.case("a ref named by an old name takes the repository's id and current name", function(assert)
	local ref: Ref = {
		source = "github",
		kind = "pull",
		key = "vocksel/orion#12",
		url = "https://github.com/vocksel/orion/pull/12",
	}

	identifyRef(moved(), ref)

	assert.eq(ref.id, "1#12")
	assert.eq(ref.key, "gummy-galaxy/orion#12")
	assert.eq(ref.url, "https://github.com/gummy-galaxy/orion/pull/12")
end)

test.case("a branch ref keeps its branch", function(assert)
	local ref: Ref = { source = "hop", kind = "branch", key = "vocksel/orion@agent/fix" }

	identifyRef(moved(), ref)

	assert.eq(ref.id, "1@agent/fix")
	assert.eq(ref.key, "gummy-galaxy/orion@agent/fix")
end)

test.case("refs with an id, from other sources, or in unknown repositories stay as they are", function(assert)
	local doc = moved()
	local withId: Ref = { source = "github", kind = "pull", key = "vocksel/orion#12", id = "9#12" }
	local jira: Ref = { source = "jira", kind = "issue", key = "ABC-1" }
	local unknown: Ref = { source = "github", kind = "pull", key = "flipbook-labs/flipbook#2" }

	identifyRef(doc, withId)
	identifyRef(doc, jira)
	identifyRef(doc, unknown)

	assert.eq(withId.key, "vocksel/orion#12")
	assert.eq(jira.id, nil)
	assert.eq(unknown.id, nil)
end)

test.case("getCurrentKey moves a key to its repository's current name", function(assert)
	local doc = moved()

	assert.eq(getCurrentKey(doc, "Vocksel/Orion#12"), "gummy-galaxy/orion#12")
	assert.eq(getCurrentKey(doc, "ABC-1"), "ABC-1")
	assert.eq(getCurrentKey(doc, "flipbook-labs/flipbook#2"), "flipbook-labs/flipbook#2")
end)
