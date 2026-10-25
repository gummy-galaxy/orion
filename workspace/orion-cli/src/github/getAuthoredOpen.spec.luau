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

test.case("authored pull requests use light fields and halve a page that times out", function(assert)
	local sizes: { string } = {}
	local authored = getAuthoredOpen(function(argv)
		local query = argv[#argv]
		table.insert(sizes, query:match("pullRequests%(first: (%d+)") :: string)
		assert.eq(query:find("mergeStateStatus", 1, true), nil)

		if #sizes < 3 then
			return testing.result(false, "", "gh: HTTP 502")
		end

		return testing.result(
			true,
			[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":1,"state":"OPEN","url":"u1","repository":{"name":"orion","owner":{"login":"vocksel"}}}],"pageInfo":{"hasNextPage":false}}}}}]]
		)
	end)

	assert.eq(table.concat(sizes, ","), "100,50,25")
	assert.eq(#authored, 1)
end)

test.case("authored pull requests raise once the smallest page times out", function(assert)
	assert.throws(function()
		getAuthoredOpen(function()
			return testing.result(false, "", "gh: HTTP 502")
		end)
	end)
end)
