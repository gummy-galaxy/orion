local json = require("@std/json")
local test = require("@std/test")

local getRefs = require("@root/refs/getRefs")
local testing = require("@root/testing")

test.case("getRefs skips malformed entries", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		refs = {
			json.object({ source = "jira", kind = "issue", key = "ORN-1" }),
			json.object({ source = "jira", kind = "issue" }),
			json.object({ source = "hop", kind = "branch", key = "vocksel/orion@main", isDone = "yes" }),
			"invalid",
		},
	})
	assert.eq(#getRefs(item), 1)
	assert.eq(getRefs(item)[1].key, "ORN-1")
end)

test.case("getRefs keeps a string id and skips a ref with any other id", function(assert)
	local item = testing.task(
		"a",
		"A",
		"todo",
		nil,
		json.object({
			refs = {
				json.object({ source = "github", kind = "pull", key = "vocksel/orion#1", id = "R_1#1" }),
				json.object({ source = "github", kind = "pull", key = "vocksel/orion#2", id = 2 }),
			},
		})
	)
	local refs = getRefs(item)
	assert.eq(#refs, 1)
	assert.eq(refs[1].id, "R_1#1")
end)
