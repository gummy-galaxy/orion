local test = require("@std/test")

local getAuthoredOpen = require("@root/github/getAuthoredOpen")
local testing = require("@root/testing")

test.case("authored pull requests include every page", function(assert)
	local calls = 0
	local authored, viewer = getAuthoredOpen(function(argv)
		calls += 1
		local query = argv[#argv]
		if calls == 1 then
			assert.eq(query:find("after:", 1, true), nil)
			return testing.result(
				true,
				[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":1,"state":"OPEN","url":"u1","repository":{"name":"orion","owner":{"login":"vocksel"}}}],"pageInfo":{"hasNextPage":true,"endCursor":"next"}}}}}]]
			)
		end
		assert.strContains(query, 'after: "next"')
		return testing.result(
			true,
			[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":2,"state":"OPEN","url":"u2","repository":{"name":"orion","owner":{"login":"vocksel"}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}]]
		)
	end)
	assert.eq(calls, 2)
	assert.eq(viewer, "vocksel")
	assert.eq(#authored, 2)
	assert.eq(authored[1].number, 1)
	assert.eq(authored[2].number, 2)
end)
