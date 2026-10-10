local test = require("@std/test")

local getRefs = require("@root/refs/getRefs")
local removeRef = require("@root/refs/removeRef")
local testing = require("@root/testing")

test.case("removeRef removes a selected identity or a kind", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		refs = {
			{ source = "jira", kind = "issue", key = "ORN-1" },
			{ source = "jira", kind = "issue", key = "ORN-2" },
		},
	})
	removeRef(item, "issue", "orn-1")
	assert.eq(getRefs(item)[1].key, "ORN-2")
	removeRef(item, "issue")
	assert.eq(item.data.refs, nil)
end)
