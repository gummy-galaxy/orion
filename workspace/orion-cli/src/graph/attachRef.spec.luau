local test = require("@std/test")

local attachRef = require("@root/graph/attachRef")
local findRef = require("@root/refs/findRef")
local testing = require("@root/testing")

test.case("attachRef adds a ref, fills in a missing repository, and refreshes the kind", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	local item = attachRef(doc, "a", {
		ref = { source = "github", kind = "pull", key = "vocksel/orion#12" },
		repo = "vocksel/orion",
	})
	assert.eq((findRef(item, "pull") :: any).key, "vocksel/orion#12")
	assert.eq(item.data.repo, "vocksel/orion")
	assert.eq(item.data.itemKind, "pr")

	attachRef(doc, "a", { ref = { source = "github", kind = "issue", key = "flipbook-labs/flipbook#1" }, repo = "x/y" })
	assert.eq(item.data.repo, "vocksel/orion")
end)

test.case("attachRef refuses groups", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group") })
	assert.throwsWith("groups don't take refs; attach it to an item", function()
		attachRef(doc, "g", { ref = { source = "jira", kind = "issue", key = "ORN-1" } })
	end)
end)
