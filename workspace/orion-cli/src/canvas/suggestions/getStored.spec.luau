local json = require("@std/json")
local test = require("@std/test")

local getStored = require("@root/canvas/suggestions/getStored")
local testing = require("@root/testing")

test.case("stored groups keep valid fields and skip malformed entries", function(assert)
	local doc = testing.createDoc({})
	doc.suggestions = json.object({
		createdAt = "2026-10-04T00:00:00Z",
		groups = {
			json.object({
				id = "s1",
				title = "Avatars",
				members = { "a", 3, "b" },
				reason = "Shared branch",
				source = "agent",
			}),
			json.object({ id = "s2", title = "Bare", members = { "c" } }),
			json.object({ id = "s3", members = { "d" } }),
			"not a group",
		},
	})
	local result = getStored(doc)
	assert.eq(result.createdAt, "2026-10-04T00:00:00Z")
	assert.eq(#result.groups, 2)
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
	assert.eq(result.groups[1].source, "agent")
	assert.eq(result.groups[2].reason, "")
	assert.eq(result.groups[2].source, "heuristic")
end)

test.case("stored suggestions are empty before any were saved", function(assert)
	local result = getStored(testing.createDoc({}))
	assert.eq(result.createdAt, nil)
	assert.eq(#result.groups, 0)
end)
