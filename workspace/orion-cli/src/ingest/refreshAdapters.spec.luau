local test = require("@std/test")

local refreshAdapters = require("@root/ingest/refreshAdapters")
local testing = require("@root/testing")

local NOW = "2026-10-04T00:00:00Z"

local function failingRunner(): any
	return testing.result(false, "")
end

test.case("refreshAdapters skips a workspace with no GitHub sources or refs", function(assert)
	local doc = testing.createDoc({ testing.task("plain", "Plain card", "todo") })
	doc.settings.sources = { { id = "jira", kind = "jira" } }
	local called = false

	local reports = refreshAdapters(doc, function(): any
		called = true
		return testing.result(true, "{}")
	end, NOW)(doc)

	assert.eq(#reports, 0)
	assert.eq(called, false)
end)

test.case("refreshAdapters refreshes GitHub for cards with pull request refs", function(assert)
	local doc = testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, {
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" } },
		}),
	})

	local reports = refreshAdapters(doc, failingRunner, NOW)(doc)

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
	doc.settings.sources = { { id = "jira", kind = "jira" } }

	assert.eq(#refreshAdapters(doc, failingRunner, NOW, "jira")(doc), 0)
end)

test.case("refreshAdapters fetches from the snapshot and applies to the document it's given", function(assert)
	local ref = { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" }
	local snapshot =
		testing.createDoc({ testing.task("ci", "Report release health", "active", nil, { refs = { ref } }) })
	local current = testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, { refs = { ref } }),
		testing.task("new", "Added meanwhile", "todo"),
	})
	local apply = refreshAdapters(snapshot, function(argv): any
		local query = argv[#argv]

		if query:find("pullRequests(first:", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		end

		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health","url":"u","state":"MERGED"}}}}]]
		)
	end, NOW)
	local reports = apply(current)

	assert.eq(reports[1].failed, nil)
	assert.eq(current.nodes[1].data.status, "done")
	assert.eq(snapshot.nodes[1].data.status, "active")
end)
