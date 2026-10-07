local test = require("@std/test")

local github = require("@root/github")
local graph = require("@root/graph")
local testing = require("@root/testing")
local types = require("@root/types")

type PullState = github.PullState
type Fetched = github.Fetched
type Doc = types.Doc

local function pull(
	state: string,
	extra: { draft: boolean?, reviewDecision: string?, reviewRequests: number? }?
): PullState
	local given: { draft: boolean?, reviewDecision: string?, reviewRequests: number? } = extra or {}
	return {
		owner = "flipbook-labs",
		name = "flipbook",
		number = 1,
		state = state,
		baseRefName = "main",
		headRefName = "feature/a",
		draft = given.draft == true,
		reviewDecision = given.reviewDecision,
		reviewRequests = given.reviewRequests or 0,
		requestedReviewers = {},
		title = "Title",
		url = "https://github.com/flipbook-labs/flipbook/pull/1",
		author = "vocksel",
		updatedAt = "2026-10-04T00:00:00Z",
		additions = 12,
		deletions = 3,
		checks = "SUCCESS",
	}
end

local function stackFixture(): (Doc, Fetched)
	local parent = pull("OPEN")
	local child = pull("OPEN")
	child.number = 2
	child.baseRefName = parent.headRefName
	child.headRefName = "feature/b"
	local doc = testing.createDoc({
		testing.task("a", "Parent", "todo", nil, { repo = "flipbook", pr = 1 }),
		testing.task("b", "Child", "todo", nil, { repo = "flipbook", pr = 2 }),
	})
	return doc,
		{
			pulls = { [github.getKey(parent)] = parent, [github.getKey(child)] = child },
			authored = {},
			viewer = "vocksel",
			discover = false,
		}
end

test.case("apply links stacked pull requests once", function(assert)
	local doc, fetched = stackFixture()
	local report = github.apply(doc, fetched, "now")
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].from, "a")
	assert.eq(doc.links[1].to, "b")
	assert.eq(doc.links[1].kind, "blocks")
	assert.eq(doc.links[1].origin, "stack")
	assert.eq(report.linked[1].from, "a")
	assert.eq(report.linked[1].to, "b")
	assert.eq(#github.apply(doc, fetched, "later").linked, 0)
	assert.eq(#doc.links, 1)
end)

test.case("apply leaves hand-made links in either direction untouched", function(assert)
	for _, pair in { { "a", "b" }, { "b", "a" } } do
		local doc, fetched = stackFixture()
		doc.links = { { id = "manual", from = pair[1], to = pair[2], kind = "related" } }
		local report = github.apply(doc, fetched, "now")
		assert.eq(#report.linked, 0)
		assert.eq(#doc.links, 1)
		assert.eq(doc.links[1].id, "manual")
		assert.eq(doc.links[1].kind, "related")
		assert.eq(doc.links[1].origin, nil)
	end
end)

test.case("apply unlinks a retargeted open stack without changing a hand-made link", function(assert)
	local doc, fetched = stackFixture()
	github.apply(doc, fetched, "now")
	table.insert(doc.links, { id = "manual", from = "a", to = "b", kind = "related" })
	fetched.pulls["flipbook-labs/flipbook#2"].baseRefName = "main"
	local report = github.apply(doc, fetched, "later")
	assert.eq(report.unlinked[1].from, "a")
	assert.eq(report.unlinked[1].to, "b")
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].id, "manual")
end)

test.case("apply keeps a merged parent's stack link after the child is retargeted", function(assert)
	local doc, fetched = stackFixture()
	github.apply(doc, fetched, "now")
	fetched.pulls["flipbook-labs/flipbook#1"].state = "MERGED"
	fetched.pulls["flipbook-labs/flipbook#2"].baseRefName = "main"
	local report = github.apply(doc, fetched, "later")
	assert.eq(#report.unlinked, 0)
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].origin, "stack")
end)

test.case("desired follows the pull request's state", function(assert)
	assert.eq(github.getDesired(pull("MERGED"), "review", "review", "vocksel"), "done")
	assert.eq(github.getDesired(pull("CLOSED"), "active", "you", "vocksel"), "deferred")
	assert.eq(github.getDesired(pull("OPEN", { draft = true }), "todo", nil, "vocksel"), "active")
	local status, who = github.getDesired(pull("OPEN", { reviewRequests = 1 }), "active", "you", "vocksel")
	assert.eq(status, "review")
	assert.eq(who, "review")
	status, who =
		github.getDesired(pull("OPEN", { reviewDecision = "CHANGES_REQUESTED" }), "review", "review", "vocksel")
	assert.eq(status, "active")
	assert.eq(who, "you")
	status, who = github.getDesired(pull("OPEN", { reviewDecision = "APPROVED" }), "review", "review", "vocksel")
	assert.eq(status, "review")
	assert.eq(who, "you")
end)

test.case("desired keeps hand-set holds while the pull request is open", function(assert)
	assert.eq(github.getDesired(pull("OPEN", { reviewRequests = 1 }), "blocked", nil, "vocksel"), "blocked")
	assert.eq(github.getDesired(pull("OPEN"), "deferred", nil, "vocksel"), "deferred")
	assert.eq(github.getDesired(pull("MERGED"), "blocked", nil, "vocksel"), "done")
end)

test.case("desired tracks requested reviews on other people's pull requests", function(assert)
	local other = pull("OPEN")
	other.author = "colleague"
	other.requestedReviewers = { "vocksel" }
	local status, who = github.getDesired(other, "todo", nil, "vocksel")
	assert.eq(status, "review")
	assert.eq(who, "you")
	other.requestedReviewers = {}
	status, who = github.getDesired(other, "review", "you", "vocksel")
	assert.eq(status, "review")
	assert.eq(who, nil)
	assert.eq(github.getDesired(other, "blocked", "ci", "vocksel"), "blocked")
	other.state = "MERGED"
	assert.eq(github.getDesired(other, "review", "you", "vocksel"), "done")
end)

test.case("refFor reads bare and owner-qualified repositories", function(assert)
	local bare = github.getRefFor(testing.task("a", "A", "todo", nil, { repo = "flipbook", pr = 5 }), "flipbook-labs")
	assert.eq(bare and github.getKey(bare), "flipbook-labs/flipbook#5")
	local qualified =
		github.getRefFor(testing.task("b", "B", "todo", nil, { repo = "vocksel/orion", pr = 2 }), "flipbook-labs")
	assert.eq(qualified and github.getKey(qualified), "vocksel/orion#2")
	assert.eq(github.getRefFor(testing.task("c", "C", "todo"), "flipbook-labs"), nil)
end)

test.case("apply stores unplaced authored pull requests with matches", function(assert)
	local doc = testing.createDoc({
		testing.task("dashboard", "Release health dashboard", "todo", nil, { repo = "flipbook" }),
	})
	local authored = pull("OPEN")
	authored.number = 670
	authored.title = "Add release health dashboard"
	local report = github.apply(doc, {
		pulls = {},
		authored = { authored },
		viewer = "vocksel",
		discover = false,
	}, "2026-10-04T18:05:00Z")
	assert.eq(#report.added, 0)
	local top = doc.github
	assert.eq(top and top.viewer, "vocksel")
	local unplaced = if top then require("@std/json").asArray(top.unplaced) else nil
	assert.eq(unplaced and #unplaced, 1)
	local entry = if unplaced then require("@std/json").asObject(unplaced[1]) else nil
	local matches = if entry then require("@std/json").asArray(entry.matches) else nil
	local first = if matches then require("@std/json").asObject(matches[1]) else nil
	assert.eq(first and first.id, "dashboard")
end)

test.case("apply keeps authored pull requests to the workspace's GitHub sources", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources =
		{ { id = "gh-vocksel", kind = "github", host = "github.com", owners = { "vocksel" }, include = { "orion" } } }
	local inside = pull("OPEN")
	inside.owner, inside.name, inside.number = "vocksel", "orion", 1
	local otherRepo = pull("OPEN")
	otherRepo.owner, otherRepo.name, otherRepo.number = "vocksel", "hop", 2
	local otherOwner = pull("OPEN")
	otherOwner.owner, otherOwner.name, otherOwner.number = "flipbook-labs", "orion", 3
	local report = github.apply(doc, {
		pulls = {},
		authored = { inside, otherRepo, otherOwner },
		viewer = "vocksel",
		discover = true,
	}, "2026-10-04T18:05:00Z")
	assert.eq(#report.added, 1)
	local added = graph.find(doc, report.added[1])
	assert.eq(added and added.data.pr, 1)
end)

test.case("discover files authored pulls in Inbox and clears unplaced", function(assert)
	local doc = testing.createDoc({})
	local authored = pull("OPEN", { draft = true })
	local report = github.apply(doc, {
		pulls = {},
		authored = { authored },
		viewer = "vocksel",
		discover = true,
	}, "2026-10-04T18:05:00Z")
	assert.eq(report.added[1], "flipbook-1")
	assert.eq(doc.nodes[2].data.itemKind, "pr")
	assert.eq(doc.nodes[2].data.status, "active")
	local top = doc.github
	local unplaced = if top then require("@std/json").asArray(top.unplaced) else nil
	assert.eq(unplaced and #unplaced, 0)
end)

test.case("fetch batches pull requests into one GraphQL query", function(assert)
	local calls = 0
	local query = ""
	local found = github.fetchPulls(function(argv)
		calls += 1
		query = argv[5]
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health","url":"u","state":"OPEN","baseRefName":"main","headRefName":"feature/a","isDraft":false,"reviewDecision":"REVIEW_REQUIRED","reviewRequests":{"totalCount":2,"nodes":[{"requestedReviewer":{"login":"vocksel"}}]},"author":{"login":"colleague"},"updatedAt":"2026-10-04T18:00:00Z","additions":120,"deletions":30,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}}},"p2":{"pullRequest":null}}}]]
		)
	end, {
		{ owner = "flipbook-labs", name = "flipbook", number = 658 },
		{ owner = "flipbook-labs", name = "flipbook", number = 9999 },
	})
	assert.eq(calls, 1)
	assert.strContains(query, "pullRequest(number: 658)")
	assert.strContains(query, "statusCheckRollup")
	assert.strContains(query, "requestedReviewer")
	assert.strContains(query, "baseRefName headRefName")
	assert.strContains(query, "title body url")
	local hit = found["flipbook-labs/flipbook#658"]
	assert.eq(hit and hit.reviewRequests, 2)
	assert.eq(hit and hit.author, "colleague")
	assert.eq(hit and hit.requestedReviewers[1], "vocksel")
	assert.eq(hit and hit.checks, "PENDING")
	assert.eq(hit and hit.baseRefName, "main")
	assert.eq(hit and hit.headRefName, "feature/a")
	assert.eq(found["flipbook-labs/flipbook#9999"], nil)
end)

test.case("fetch rejects repository names that would break the query", function(assert)
	assert.throws(function()
		github.fetchPulls(function()
			return testing.result(true, "{}")
		end, { { owner = 'x") { evil }', name = "y", number = 1 } })
	end)
end)

test.case("authored pull requests include every page", function(assert)
	local calls = 0
	local authored, viewer = github.getAuthoredOpen(function(argv)
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

test.case("collect batches pull request lookups by host", function(assert)
	local doc = testing.createDoc({
		testing.task("public", "Public", "todo", nil, { repo = "flipbook", pr = 1 }),
		testing.task(
			"private",
			"Private",
			"todo",
			nil,
			{ repo = "Roblox/avatar", pr = 2, host = "github.example.com" }
		),
	})
	local batches = {}
	github.collect(doc, function(argv)
		local query = argv[#argv]
		if query:find("pullRequests(first:", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		elseif query:find("search(query:", 1, true) then
			return testing.result(true, [[{"data":{"search":{"nodes":[]}}}]])
		end
		table.insert(batches, argv)
		return testing.result(true, [[{"data":{}}]])
	end, false)
	assert.eq(#batches, 2)
	local hosts: { [string]: boolean } = {}
	for _, argv in batches do
		if argv[3] == "--hostname" then
			hosts[argv[4]] = true
		else
			hosts["github.com"] = true
		end
	end
	assert.eq(hosts["github.com"], true)
	assert.eq(hosts["github.example.com"], true)
end)

test.case("apply updates statuses, reports what's missing, and files new pull requests in an Inbox", function(assert)
	local doc = testing.createDoc({
		testing.task("a", "Mine", "active", nil, { repo = "flipbook", pr = 1, who = "you" }),
		testing.task("b", "Gone", "todo", nil, { repo = "flipbook", pr = 2 }),
	})
	local merged = pull("MERGED")
	local report = github.apply(doc, {
		pulls = { ["flipbook-labs/flipbook#1"] = merged },
		authored = {},
		viewer = "vocksel",
		discover = false,
	}, "2026-10-04T00:00:00Z")
	assert.eq(#report.changes, 1)
	assert.eq(report.changes[1].toStatus, "done")
	assert.eq(report.missing[1], "b")
	assert.eq(#report.added, 0)
	local recorded = require("@std/json").asObject(doc.nodes[1].data.github)
	assert.eq(recorded and recorded.checks, "SUCCESS")
	assert.eq(recorded and recorded.additions, 12)
end)
