local test = require("@std/test")

local findRef = require("@root/canvas/refs/findRef")
local testing = require("@root/testing")

test.case("findRef matches kind and key without case", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		refs = {
			{ source = "jira", kind = "issue", key = "ORN-1" },
			{ source = "github", kind = "issue", key = "vocksel/orion#1" },
		},
	})
	assert.eq((findRef(item, "issue") :: any).key, "ORN-1")
	assert.eq((findRef(item, "issue", "Vocksel/Orion#1") :: any).source, "github")
	assert.eq(findRef(item, "pull", "ORN-1"), nil)
end)
