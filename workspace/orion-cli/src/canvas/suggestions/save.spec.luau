local test = require("@std/test")

local getStored = require("@root/canvas/suggestions/getStored")
local save = require("@root/canvas/suggestions/save")
local testing = require("@root/testing")

test.case("saved suggestions read back unchanged", function(assert)
	local doc = testing.createDoc({})
	save(doc, {
		createdAt = "2026-10-04T00:00:00Z",
		groups = {
			{ id = "s1", title = "Avatars", members = { "a", "b" }, reason = "Shared branch", source = "heuristic" },
		},
	})

	local result = getStored(doc)
	assert.eq(result.createdAt, "2026-10-04T00:00:00Z")
	assert.eq(#result.groups, 1)
	assert.eq(result.groups[1].title, "Avatars")
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
end)
