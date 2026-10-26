local test = require("@std/test")

local getInvolvedAsync = require("@root/github/getInvolvedAsync")
local testing = require("@root/testing")

test.case("involved search filters repositories", function(assert)
	local calls = 0
	local pulls, issues, viewer = getInvolvedAsync(function()
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

test.case("involved search halves a page that times out and keeps that size", function(assert)
	local sizes: { string } = {}
	getInvolvedAsync(function(argv)
		local query = argv[#argv]

		if query:find("viewer { login }", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel"}}}]])
		end

		local size = query:match("first: (%d+)") :: string
		table.insert(sizes, size)

		if size == "100" then
			return testing.result(false, "", "gh: HTTP 502")
		end

		local hasNext = if query:find("after:", 1, true) then "false" else "true"
		return testing.result(
			true,
			`\{"data":\{"search":\{"nodes":[],"pageInfo":\{"hasNextPage":{hasNext},"endCursor":"next"}}}}`
		)
	end, "github.com", { "vocksel" }, "2026-10-01", nil, nil)

	assert.eq(sizes[1], "100")
	assert.eq(sizes[2], "50")
	assert.eq(sizes[3], "50")
end)
