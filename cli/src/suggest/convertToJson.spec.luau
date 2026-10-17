local json = require("@std/json")
local test = require("@std/test")

local convertToJson = require("@root/suggest/convertToJson")

test.case("converted suggestions keep each group's fields", function(assert)
	local value = convertToJson({
		createdAt = "2026-10-04T00:00:00Z",
		groups = {
			{ id = "s1", title = "Avatars", members = { "a", "b" }, reason = "Shared branch", source = "heuristic" },
		},
	})
	local groups = json.asArray(value.groups) :: json.Array
	local group = json.asObject(groups[1] :: json.Value) :: json.Object

	assert.eq(value.createdAt, "2026-10-04T00:00:00Z")
	assert.eq(#groups, 1)
	assert.eq(group.id, "s1")
	assert.eq(group.title, "Avatars")
	assert.eq(group.reason, "Shared branch")
	assert.eq(group.source, "heuristic")
end)
