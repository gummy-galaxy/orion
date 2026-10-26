local test = require("@std/test")

local refreshAdaptersAsync = require("@root/ingest/refreshAdaptersAsync")
local testing = require("@root/testing")

local NOW = "2026-10-04T00:00:00Z"

local function failingRunner(): any
	return testing.result(false, "")
end

test.case("refreshAdaptersAsync skips a workspace with no GitHub sources or refs", function(assert)
	local doc = testing.createDoc({ testing.task("plain", "Plain card", "todo") })
	doc.settings.sources = { { id = "jira", kind = "jira" } }
	local called = false

	local reports = refreshAdaptersAsync(doc, function(): any
		called = true
		return testing.result(true, "{}")
	end, NOW)(doc)

	assert.eq(#reports, 0)
	assert.eq(called, false)
end)

test.case("refreshAdaptersAsync refreshes GitHub for cards with pull request refs", function(assert)
	local doc = testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, {
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" } },
		}),
	})

	local reports = refreshAdaptersAsync(doc, failingRunner, NOW)(doc)

	assert.eq(#reports, 1)
	assert.eq(reports[1].kind, "github")
	assert.eq(reports[1].report, nil)
	assert.neq(reports[1].failed, nil)
end)

test.case("refreshAdaptersAsync limits a selected source to its own kind", function(assert)
	local doc = testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, {
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" } },
		}),
	})
	doc.settings.sources = { { id = "jira", kind = "jira" } }

	assert.eq(#refreshAdaptersAsync(doc, failingRunner, NOW, "jira")(doc), 0)
end)

test.case("refreshAdaptersAsync fetches from the snapshot and applies to the document it's given", function(assert)
	local ref = { source = "github", kind = "pull", key = "flipbook-labs/flipbook#658" }
	local snapshot =
		testing.createDoc({ testing.task("ci", "Report release health", "active", nil, { refs = { ref } }) })
	local current = testing.createDoc({
		testing.task("ci", "Report release health", "active", nil, { refs = { ref } }),
		testing.task("new", "Added meanwhile", "todo"),
	})
	local apply = refreshAdaptersAsync(snapshot, function(argv): any
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
