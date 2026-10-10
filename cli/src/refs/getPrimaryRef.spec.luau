local test = require("@std/test")

local getPrimaryRef = require("@root/refs/getPrimaryRef")
local testing = require("@root/testing")

test.case("getPrimaryRef prefers the first linked ref", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		refs = {
			{ source = "hop", kind = "branch", key = "vocksel/orion@main" },
			{ source = "jira", kind = "issue", key = "ORN-1", url = "https://jira.example/ORN-1" },
		},
	})
	assert.eq((getPrimaryRef(item) :: any).key, "ORN-1")
	assert.eq(getPrimaryRef(testing.task("b", "B", "todo")), nil)
end)
