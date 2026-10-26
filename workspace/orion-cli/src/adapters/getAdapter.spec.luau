local test = require("@std/test")

local getAdapter = require("@root/adapters/getAdapter")

test.case("adapter registry resolves each source and rejects unknown kinds", function(assert)
	for _, kind in { "github", "jira", "hop" } do
		local adapter = getAdapter(kind)
		assert.eq(adapter.kind, kind)
		assert.eq(type(adapter.collectAsync), "function")
		assert.eq(type(adapter.createSource), "function")
	end

	assert.eq(type(getAdapter("github").refreshAsync), "function")
	assert.throws(function()
		getAdapter("missing")
	end)
end)
