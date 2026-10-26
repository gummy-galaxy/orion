local test = require("@std/test")

local collectAsync = require("@root/adapters/jira/collectAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

local NOW = "2026-10-04T00:00:00Z"

test.case("Jira adapter parses issue state and details into records", function(assert)
	local doc = testing.createDoc({})
	local source: Source = { id = "jira", kind = "jira", browse = "https://jira.example.com/browse" }
	local records = collectAsync(source, function(argv)
		assert.eq(argv, { "acli", "jira" })
		return testing.result(
			true,
			'{"issues":[{"key":"ABC-1","fields":{"summary":"Work","status":{"name":"Done","statusCategory":{"key":"done"}},"issuetype":{"name":"Story"},"epic":{"key":"ABC-0","summary":"Epic"},"updated":"2026-10-03T00:00:00Z"}}]}'
		)
	end, { now = NOW, since = "2026-09-20", doc = doc, commands = { jira = { "acli", "jira" } } })
	assert.eq(#records, 1)
	assert.eq(records[1].ref.key, "ABC-1")
	assert.eq(records[1].ref.url, "https://jira.example.com/browse/ABC-1")
	assert.eq(records[1].ref.isDone, true)
	local details = records[1].ref.details
	assert.eq(details and details.epicKey, "ABC-0")
	assert.eq(records[1].status, "done")
	assert.eq(records[1].who, nil)
	assert.eq(#doc.nodes, 0)
end)
