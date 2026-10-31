local test = require("@std/test")

local adapterTypes = require("@root/sources/types")
local getAdapter = require("@root/sources/getAdapter")

type SourceVerbs = adapterTypes.SourceVerbs

test.case("adapter registry resolves each source and rejects unknown kinds", function(assert)
	for _, kind in { "github", "jira", "hop" } do
		local adapter = getAdapter(kind)
		local verbs = adapter.source :: SourceVerbs
		assert.eq(adapter.kind, kind)
		assert.eq(type(verbs.collectAsync), "function")
		assert.eq(type(adapter.createSource), "function")
	end

	assert.eq(type((getAdapter("github").source :: SourceVerbs).refreshAsync), "function")
	assert.throws(function()
		getAdapter("missing")
	end)
end)
