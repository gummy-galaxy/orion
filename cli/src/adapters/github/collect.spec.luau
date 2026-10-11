local test = require("@std/test")

local collect = require("@root/adapters/github/collect")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

local NOW = "2026-10-04T00:00:00Z"

test.case("GitHub adapter collects pull and issue records without writing cards", function(assert)
	local doc = testing.createDoc({})
	local source: Source = { id = "gh-owner", kind = "github", host = "github.com", owners = { "owner" } }
	local function run(argv: { string })
		local query = argv[#argv]

		if query:find("viewer { login }", 1, true) then
			return testing.result(true, '{"data":{"viewer":{"login":"me"}}}')
		elseif query:find("is:open is:pr", 1, true) then
			return testing.result(
				true,
				'{"data":{"search":{"nodes":[{"number":2,"title":"Fix ABC-1","body":"Closes #3","url":"https://github.com/owner/repo/pull/2","state":"OPEN","isDraft":true,"headRefName":"ABC-1-fix","author":{"login":"me"},"repository":{"name":"repo","owner":{"login":"owner"}}}],"pageInfo":{"hasNextPage":false}}}}'
			)
		elseif query:find("is:open is:issue", 1, true) then
			return testing.result(
				true,
				'{"data":{"search":{"nodes":[{"number":3,"title":"Issue","url":"https://github.com/owner/repo/issues/3","repository":{"name":"repo","owner":{"login":"owner"}}}],"pageInfo":{"hasNextPage":false}}}}'
			)
		end

		return testing.result(true, '{"data":{"search":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}')
	end

	local records = collect(source, run, { now = NOW, since = "2026-09-20", doc = doc })
	assert.eq(#records, 2)
	assert.eq(records[1].ref.key, "owner/repo#2")
	assert.eq(records[1].ref.status, "draft")
	assert.eq(records[1].itemKind, "pr")
	assert.eq(records[1].mentionText, "Fix ABC-1 ABC-1-fix Closes #3")
	local getStatus = records[1].getStatus
	assert.eq(getStatus ~= nil, true)
	if getStatus then
		assert.eq(select(1, getStatus("todo", nil)), "active")
	end
	assert.eq(records[2].ref.kind, "issue")
	assert.eq(records[2].createWho, "you")
	assert.eq(#doc.nodes, 0)
end)
