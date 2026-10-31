local test = require("@std/test")

local collectAsync = require("@root/sources/hop/collectAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

local NOW = "2026-10-04T00:00:00Z"

test.case("hop adapter merges worktree and session activity without writing cards", function(assert)
	local doc = testing.createDoc({})
	local source: Source = { id = "hop", kind = "hop" }
	local records = collectAsync(source, function(argv)
		if argv[2] == "list" then
			return testing.result(
				true,
				'{"worktrees":[{"branch":"feature/ABC-1","onDefaultBranch":false,"lastActivity":1791072000,'
					.. '"repository":{"name":"owner/repo"}}]}'
			)
		end

		return testing.result(
			true,
			'[{"title":"Inspect","repository":"owner/repo","branch":"feature/ABC-1","updatedAt":1791072000}]'
		)
	end, { now = NOW, since = "2026-09-20", doc = doc, commands = {} })
	assert.eq(#records, 1)
	assert.eq(records[1].ref.key, "owner/repo@feature/ABC-1")
	local details = records[1].ref.details
	assert.eq(details and details.sessions, { "Inspect" })
	assert.eq(records[1].createStatus, "active")
	assert.eq(records[1].isUpdateOnly, false)
	assert.eq(#doc.nodes, 0)
end)
