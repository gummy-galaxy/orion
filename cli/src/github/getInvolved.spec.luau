local test = require("@std/test")

local getInvolved = require("@root/github/getInvolved")
local testing = require("@root/testing")

test.case("involved search filters repositories", function(assert)
	local calls = 0
	local pulls, issues, viewer = getInvolved(function()
		calls += 1
		if calls == 1 then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel"}}}]])
		end
		return testing.result(
			true,
			[[{"data":{"search":{"nodes":[{"number":14,"title":"Issue","url":"u","repository":{"name":"orion","owner":{"login":"vocksel"}}}],"pageInfo":{"hasNextPage":false}}}}]]
		)
	end, "github.com", { "vocksel" }, "2026-10-01", { "orion" }, nil)
	assert.eq(viewer, "vocksel")
	assert.eq(#pulls, 0)
	assert.eq(#issues, 1)
end)
