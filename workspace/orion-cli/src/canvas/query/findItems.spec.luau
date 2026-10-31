local json = require("@std/json")
local test = require("@std/test")

local findItems = require("@root/canvas/query/findItems")
local testing = require("@root/testing")

test.case("find ranks an exact label first, then label, ref, and note matches", function(assert)
	local doc = testing.createDoc({
		testing.task("note-match", "Plan the launch", "todo", nil, { note = "Confirm the release date" }),
		testing.task("ref-match", "Fix the crash", "todo", nil, {
			refs = { json.object({ source = "github", kind = "pull", key = "vocksel/orion#303" }) },
		}),
		testing.task("contains", "Release the build", "todo"),
		testing.task("exact", "Release", "todo"),
	})
	local result = findItems({ { name = "default", doc = doc } }, "release", 20)
	assert.eq(result.total, 3)
	assert.eq(result.hits[1].item.id, "exact")
	assert.eq(result.hits[2].item.id, "contains")
	assert.eq(result.hits[3].item.id, "note-match")

	local refs = findItems({ { name = "default", doc = doc } }, "vocksel/orion#303", 20)
	assert.eq(refs.total, 1)
	assert.eq(refs.hits[1].item.id, "ref-match")
end)

test.case("find caps the hits but still reports the total, and keeps canvas order", function(assert)
	local first = testing.createDoc({ testing.task("one", "Alpha item", "todo") })
	local second = testing.createDoc({ testing.task("two", "Alpha second", "todo") })
	local result = findItems({ { name = "a", doc = first }, { name = "b", doc = second } }, "alpha", 1)
	assert.eq(result.total, 2)
	assert.eq(#result.hits, 1)
	assert.eq(result.hits[1].name, "a")
	assert.eq(result.hits[1].item.id, "one")
end)

test.case("find takes its text literally, quotes and backslashes included", function(assert)
	local doc = testing.createDoc({
		testing.task("quoted", [[Say "hi" to \ the team]], "todo"),
		testing.task("plain", "Say hi", "todo"),
	})
	local result = findItems({ { name = "default", doc = doc } }, [["hi" to \]], 20)
	assert.eq(result.total, 1)
	assert.eq(result.hits[1].item.id, "quoted")
	assert.eq(findItems({ { name = "default", doc = doc } }, "%", 20).total, 0)
end)

test.case("find needs text", function(assert)
	assert.throws(function()
		findItems({}, "", 20)
	end)
end)
