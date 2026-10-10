local test = require("@std/test")

local applyPulls = require("@root/github/applyPulls")
local findRef = require("@root/refs/findRef")
local getKey = require("@root/github/getKey")
local githubTypes = require("@root/github/types")
local graph = require("@root/graph")
local testing = require("@root/testing")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Fetched = githubTypes.Fetched
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
		testing.task("a", "Parent", "todo", nil, {
			repo = "flipbook-labs/flipbook",
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#1" } },
		}),
		testing.task("b", "Child", "todo", nil, {
			repo = "flipbook-labs/flipbook",
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#2" } },
		}),
	})
	return doc,
		{
			pulls = { [getKey(parent)] = parent, [getKey(child)] = child },
			authored = {},
			viewer = "vocksel",
			discover = false,
		}
end

test.case("apply links stacked pull requests once", function(assert)
	local doc, fetched = stackFixture()
	local report = applyPulls(doc, fetched, "now")
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].from, "a")
	assert.eq(doc.links[1].to, "b")
	assert.eq(doc.links[1].kind, "blocks")
	assert.eq(doc.links[1].origin, "stack")
	assert.eq(report.linked[1].from, "a")
	assert.eq(report.linked[1].to, "b")
	assert.eq(#applyPulls(doc, fetched, "later").linked, 0)
	assert.eq(#doc.links, 1)
end)

test.case("apply leaves hand-made links in either direction untouched", function(assert)
	for _, pair in { { "a", "b" }, { "b", "a" } } do
		local doc, fetched = stackFixture()
		doc.links = { { id = "manual", from = pair[1], to = pair[2], kind = "related" } }
		local report = applyPulls(doc, fetched, "now")
		assert.eq(#report.linked, 0)
		assert.eq(#doc.links, 1)
		assert.eq(doc.links[1].id, "manual")
		assert.eq(doc.links[1].kind, "related")
		assert.eq(doc.links[1].origin, nil)
	end
end)

test.case("apply unlinks a retargeted open stack without changing a hand-made link", function(assert)
	local doc, fetched = stackFixture()
	applyPulls(doc, fetched, "now")
	table.insert(doc.links, { id = "manual", from = "a", to = "b", kind = "related" })
	fetched.pulls["flipbook-labs/flipbook#2"].baseRefName = "main"
	local report = applyPulls(doc, fetched, "later")
	assert.eq(report.unlinked[1].from, "a")
	assert.eq(report.unlinked[1].to, "b")
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].id, "manual")
end)

test.case("apply keeps a merged parent's stack link after the child is retargeted", function(assert)
	local doc, fetched = stackFixture()
	applyPulls(doc, fetched, "now")
	fetched.pulls["flipbook-labs/flipbook#1"].state = "MERGED"
	fetched.pulls["flipbook-labs/flipbook#2"].baseRefName = "main"
	local report = applyPulls(doc, fetched, "later")
	assert.eq(#report.unlinked, 0)
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].origin, "stack")
end)

test.case("apply stores unplaced authored pull requests with matches", function(assert)
	local doc = testing.createDoc({
		testing.task("dashboard", "Release health dashboard", "todo", nil, { repo = "flipbook-labs/flipbook" }),
	})
	local authored = pull("OPEN")
	authored.number = 670
	authored.title = "Add release health dashboard"
	local report = applyPulls(doc, {
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
	local report = applyPulls(doc, {
		pulls = {},
		authored = { inside, otherRepo, otherOwner },
		viewer = "vocksel",
		discover = true,
	}, "2026-10-04T18:05:00Z")
	assert.eq(#report.added, 1)
	local added = graph.find(doc, report.added[1])
	assert.eq(added and (findRef(added, "pull") :: types.Ref).key, "vocksel/orion#1")
end)

test.case("discover files authored pulls in Inbox and clears unplaced", function(assert)
	local doc = testing.createDoc({})
	local authored = pull("OPEN", { draft = true })
	local report = applyPulls(doc, {
		pulls = {},
		authored = { authored },
		viewer = "vocksel",
		discover = true,
	}, "2026-10-04T18:05:00Z")
	assert.eq(report.added[1], "flipbook-labs-flipbook-1")
	assert.eq(doc.nodes[2].data.itemKind, "pr")
	assert.eq(doc.nodes[2].data.status, "active")
	local top = doc.github
	local unplaced = if top then require("@std/json").asArray(top.unplaced) else nil
	assert.eq(unplaced and #unplaced, 0)
end)

test.case("apply updates statuses, reports what's missing, and files new pull requests in an Inbox", function(assert)
	local doc = testing.createDoc({
		testing.task("a", "Mine", "active", nil, {
			repo = "flipbook-labs/flipbook",
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#1" } },
			who = "you",
		}),
		testing.task("b", "Gone", "todo", nil, {
			repo = "flipbook-labs/flipbook",
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#2" } },
		}),
	})
	local merged = pull("MERGED")
	local report = applyPulls(doc, {
		pulls = { ["flipbook-labs/flipbook#1"] = merged },
		authored = {},
		viewer = "vocksel",
		discover = false,
	}, "2026-10-04T00:00:00Z")
	assert.eq(#report.changes, 1)
	assert.eq(report.changes[1].toStatus, "done")
	assert.eq(report.missing[1], "b")
	assert.eq(#report.added, 0)
	local recorded = (findRef(doc.nodes[1], "pull") :: types.Ref).details
	assert.eq(recorded and recorded.checks, "SUCCESS")
	assert.eq(recorded and recorded.additions, 12)
end)
