local test = require("@std/test")

local refreshAdapters = require("@root/ingest/refreshAdapters")
local testing = require("@root/testing")

local NOW = "2026-10-04T00:00:00Z"

local function failingRunner(): any
	return testing.result(false, "")
end

test.case("refreshAdapters skips a workspace with no GitHub sources or refs", function(assert)
	local doc = testing.createDoc({ testing.task("plain", "Plain card", "todo") })
	doc.settings.sources = { { id = "jira", kind = "jira", command = { "acli" } } }
	local called = false

	local reports = refreshAdapters(doc, function(): any
		called = true
		return testing.result(true, "{}")
	end, NOW)

	assert.eq(#reports, 0)
	assert.eq(called, false)
end)

test.case("refreshAdapters refreshes GitHub for cards with pull request refs", function(assert)
	local doc = testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, {
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" } },
		}),
	})

	local reports = refreshAdapters(doc, failingRunner, NOW)

	assert.eq(#reports, 1)
	assert.eq(reports[1].kind, "github")
	assert.eq(reports[1].report, nil)
	assert.neq(reports[1].failed, nil)
end)

test.case("refreshAdapters limits a selected source to its own kind", function(assert)
	local doc = testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, {
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" } },
		}),
	})
	doc.settings.sources = { { id = "jira", kind = "jira", command = { "acli" } } }

	assert.eq(#refreshAdapters(doc, failingRunner, NOW, "jira"), 0)
end)
