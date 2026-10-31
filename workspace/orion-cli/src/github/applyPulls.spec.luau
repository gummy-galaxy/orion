local json = require("@std/json")
local test = require("@std/test")

local applyPulls = require("@root/github/applyPulls")
local findRef = require("@root/refs/findRef")
local getKey = require("@root/github/getKey")
local githubTypes = require("@root/github/types")
local setFields = require("@root/graph/setFields")
local testing = require("@root/testing")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Fetched = githubTypes.Fetched
type Doc = types.Doc

local pull = testing.pull

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
			checked = { [getKey(parent)] = true, [getKey(child)] = true },
			authored = {},
			viewer = "vocksel",
			failures = {},
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
	applyPulls(doc, {
		pulls = {},
		checked = {},
		authored = { authored },
		viewer = "vocksel",
		failures = {},
	}, "2026-10-04T18:05:00Z")
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
	applyPulls(doc, {
		pulls = { [getKey(inside)] = inside, [getKey(otherRepo)] = otherRepo, [getKey(otherOwner)] = otherOwner },
		checked = {},
		authored = { inside, otherRepo, otherOwner },
		viewer = "vocksel",
		failures = {},
	}, "2026-10-04T18:05:00Z")
	local top = doc.github
	local unplaced = if top then json.asArray(top.unplaced) else nil
	assert.eq(unplaced and #unplaced, 1)
	local entry = if unplaced then json.asObject(unplaced[1]) else nil
	assert.eq(entry and entry.repo, "vocksel/orion")
end)

test.case("apply updates statuses, and reports what's missing", function(assert)
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
		checked = { ["flipbook-labs/flipbook#1"] = true, ["flipbook-labs/flipbook#2"] = true },
		authored = {},
		viewer = "vocksel",
		failures = {},
	}, "2026-10-04T00:00:00Z")
	assert.eq(#report.changes, 1)
	assert.eq(report.changes[1].toStatus, "done")
	assert.eq(report.missing[1], "b")
	local recorded = (findRef(doc.nodes[1], "pull") :: types.Ref).details
	assert.eq(recorded and recorded.checks, "SUCCESS")
	assert.eq(recorded and recorded.additions, 12)
end)

local BRANCH = "flipbook-labs/flipbook@feature/a"

local function branchRef(key: string): json.Object
	return json.object({ source = "hop", kind = "branch", key = key })
end

local function branchCard(id: string, label: string, status: string, refs: { json.Object }?): types.Item
	return testing.task(id, label, status, nil, {
		repo = "flipbook-labs/flipbook",
		refs = refs or { branchRef(BRANCH) },
	})
end

local function unplacedOf(doc: Doc): { json.Object }
	local found: { json.Object } = {}
	local values = if doc.github then json.asArray(doc.github.unplaced) else nil

	for _, raw in values or {} do
		table.insert(found, json.asObject(raw) :: json.Object)
	end

	return found
end

-- Your own open pull requests are listed with light fields, and
-- collectPullsAsync fetches the full state of the ones that can become cards.
local function authoredOnly(authored: PullState): Fetched
	return {
		pulls = { [getKey(authored)] = authored },
		checked = {},
		authored = { authored },
		viewer = "vocksel",
		failures = {},
	}
end

test.case("a new pull request attaches to the one card recorded on its head branch", function(assert)
	local doc = testing.createDoc({ branchCard("work", "Dashboard work", "todo") })
	local report = applyPulls(doc, authoredOnly(pull("OPEN")), "2026-10-04T18:05:00Z")

	assert.eq(#report.attached, 1)
	assert.eq(report.attached[1].id, "work")
	assert.eq(report.attached[1].pull, "flipbook-labs/flipbook#1")
	assert.eq(#unplacedOf(doc), 0)

	local item = doc.nodes[1]
	assert.eq((findRef(item, "pull") :: types.Ref).key, "flipbook-labs/flipbook#1")
	assert.eq(testing.primaryType(item), "pr")
	assert.eq(item.data.status, "review")
	assert.eq(report.changes[1].toStatus, "review")
end)

test.case("an attached pull request is tracked by the next sync instead of attached again", function(assert)
	local doc = testing.createDoc({ branchCard("work", "Dashboard work", "todo") })
	local authored = pull("OPEN")
	applyPulls(doc, authoredOnly(authored), "2026-10-04T18:05:00Z")

	local fetched = authoredOnly(authored)
	fetched.checked["flipbook-labs/flipbook#1"] = true
	local report = applyPulls(doc, fetched, "2026-10-04T19:00:00Z")

	assert.eq(#report.attached, 0)
	assert.eq(#report.missing, 0)
	assert.eq(report.checked, 1)
end)

test.case("a head branch no card records falls back to title matches", function(assert)
	local doc = testing.createDoc({
		testing.task("dashboard", "Add release health dashboard", "todo", nil, { repo = "flipbook-labs/flipbook" }),
		branchCard("other", "Unrelated work", "todo", { branchRef("flipbook-labs/flipbook@other") }),
	})
	local report = applyPulls(doc, authoredOnly(pull("OPEN")), "2026-10-04T18:05:00Z")

	assert.eq(#report.attached, 0)
	local unplaced = unplacedOf(doc)
	assert.eq(#unplaced, 1)
	local first = json.asObject((json.asArray(unplaced[1].matches) or {})[1]) :: json.Object
	assert.eq(first.id, "dashboard")
end)

test.case("a branch with the same name in another repository does not match", function(assert)
	local doc = testing.createDoc({
		testing.task("work", "Dashboard work", "todo", nil, {
			repo = "flipbook-labs/other",
			refs = { branchRef("flipbook-labs/other@feature/a") },
		}),
	})
	local report = applyPulls(doc, authoredOnly(pull("OPEN")), "2026-10-04T18:05:00Z")

	assert.eq(#report.attached, 0)
	assert.eq(#unplacedOf(doc), 1)
	assert.eq(findRef(doc.nodes[1], "pull"), nil)
end)

test.case("two cards on one head branch leave the pull request unplaced and list both", function(assert)
	local doc = testing.createDoc({
		branchCard("first", "Dashboard work", "todo"),
		branchCard("second", "Dashboard follow-up", "active"),
	})
	local report = applyPulls(doc, authoredOnly(pull("OPEN")), "2026-10-04T18:05:00Z")

	assert.eq(#report.attached, 0)
	assert.eq(findRef(doc.nodes[1], "pull"), nil)
	assert.eq(findRef(doc.nodes[2], "pull"), nil)

	local unplaced = unplacedOf(doc)
	assert.eq(#unplaced, 1)
	local matches = json.asArray(unplaced[1].matches) or {}
	assert.eq(#matches, 2)
	local first = json.asObject(matches[1]) :: json.Object
	local second = json.asObject(matches[2]) :: json.Object
	assert.eq(first.id, "first")
	assert.eq(first.score, 1)
	assert.eq(second.id, "second")
end)

test.case("cards that already track a pull request or are done are not branch matches", function(assert)
	local tracking = branchCard("tracking", "Tracked work", "active", {
		branchRef(BRANCH),
		json.object({ source = "github", kind = "pull", key = "flipbook-labs/flipbook#9" }),
	})
	local finished = branchCard("finished", "Finished work", "done")
	local doc = testing.createDoc({ tracking, finished })
	local report = applyPulls(doc, authoredOnly(pull("OPEN")), "2026-10-04T18:05:00Z")

	assert.eq(#report.attached, 0)
	assert.eq(#unplacedOf(doc), 1)
	assert.eq(findRef(finished, "pull"), nil)
end)

test.case("a branch match attaches to its card", function(assert)
	local doc = testing.createDoc({ branchCard("work", "Dashboard work", "todo") })
	local report = applyPulls(doc, authoredOnly(pull("OPEN")), "2026-10-04T18:05:00Z")

	assert.eq(#report.attached, 1)
	assert.eq(#unplacedOf(doc), 0)
end)

local function trackedDoc(status: string, closedDeferral: boolean?): Doc
	return testing.createDoc({
		testing.task("a", "Work", status, nil, {
			repo = "flipbook-labs/flipbook",
			deferredByClosedPull = closedDeferral,
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#1" } },
		}),
	})
end

local function fetchedWith(state: string): Fetched
	local tracked = pull(state)
	return {
		pulls = { [getKey(tracked)] = tracked },
		checked = { [getKey(tracked)] = true },
		authored = {},
		viewer = "vocksel",
		failures = {},
	}
end

test.case("a refresh defers a card whose pull request closed and marks the deferral as its own", function(assert)
	local doc = trackedDoc("active")
	applyPulls(doc, fetchedWith("CLOSED"), "now")
	assert.eq(doc.nodes[1].data.status, "deferred")
	assert.eq(doc.nodes[1].data.deferredByClosedPull, true)
end)

test.case("a refresh moves a card deferred by a closed pull request back once it reopens", function(assert)
	local doc = trackedDoc("active")
	applyPulls(doc, fetchedWith("CLOSED"), "now")
	local report = applyPulls(doc, fetchedWith("OPEN"), "later")
	assert.eq(doc.nodes[1].data.status, "review")
	assert.eq(doc.nodes[1].data.deferredByClosedPull, nil)
	assert.eq(report.changes[1].fromStatus, "deferred")
	assert.eq(report.changes[1].toStatus, "review")
end)

test.case("a card deferred by a closed pull request follows a new open pull request it's pointed at", function(assert)
	local doc = trackedDoc("active")
	applyPulls(doc, fetchedWith("CLOSED"), "now")
	local successor = pull("OPEN")
	successor.number = 2
	local refs: json.Array = { json.object({ source = "github", kind = "pull", key = "flipbook-labs/flipbook#2" }) }
	doc.nodes[1].data.refs = refs
	local fetched = fetchedWith("OPEN")
	fetched.pulls = { [getKey(successor)] = successor }
	applyPulls(doc, fetched, "later")
	assert.eq(doc.nodes[1].data.status, "review")
	assert.eq(doc.nodes[1].data.deferredByClosedPull, nil)
end)

test.case("a deferral someone set stays deferred when its pull request closes or reopens", function(assert)
	local doc = trackedDoc("deferred")
	applyPulls(doc, fetchedWith("CLOSED"), "now")
	assert.eq(doc.nodes[1].data.status, "deferred")
	assert.eq(doc.nodes[1].data.deferredByClosedPull, nil)
	applyPulls(doc, fetchedWith("OPEN"), "later")
	assert.eq(doc.nodes[1].data.status, "deferred")
	assert.eq(doc.nodes[1].data.deferredByClosedPull, nil)
end)

test.case("a deferral someone set stays when the card is pointed at another open pull request", function(assert)
	local doc = trackedDoc("deferred")
	local successor = pull("OPEN")
	successor.number = 2
	local refs: json.Array = { json.object({ source = "github", kind = "pull", key = "flipbook-labs/flipbook#2" }) }
	doc.nodes[1].data.refs = refs
	local fetched = fetchedWith("OPEN")
	fetched.pulls = { [getKey(successor)] = successor }
	applyPulls(doc, fetched, "now")
	assert.eq(doc.nodes[1].data.status, "deferred")
end)

test.case("setting a status by hand takes over a refresh deferral", function(assert)
	local doc = trackedDoc("active")
	applyPulls(doc, fetchedWith("CLOSED"), "now")
	setFields(doc, "a", { status = "deferred" })
	assert.eq(doc.nodes[1].data.deferredByClosedPull, nil)
	applyPulls(doc, fetchedWith("OPEN"), "later")
	assert.eq(doc.nodes[1].data.status, "deferred")
end)

test.case("a card that wasn't fetched keeps its state and isn't reported missing", function(assert)
	local doc = testing.createDoc({
		testing.task("merged", "Merged", "done", nil, {
			repo = "flipbook-labs/flipbook",
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#1", status = "merged" } },
		}),
	})
	local report = applyPulls(doc, {
		pulls = {},
		checked = {},
		authored = {},
		viewer = "vocksel",
		failures = { "2 pull requests on github.com: gh: HTTP 502" },
	}, "2026-10-04T18:05:00Z")

	assert.eq(#report.missing, 0)
	assert.eq(report.checked, 0)
	assert.eq(#report.changes, 0)
	assert.eq(report.failures[1], "2 pull requests on github.com: gh: HTTP 502")
end)

test.case("a branch match without its full state stays unplaced until it's fetched", function(assert)
	local doc = testing.createDoc({ branchCard("work", "Dashboard work", "todo") })
	local fetched = authoredOnly(pull("OPEN"))
	fetched.pulls = {}
	local report = applyPulls(doc, fetched, "2026-10-04T18:05:00Z")

	assert.eq(#report.attached, 0)
	assert.eq(findRef(doc.nodes[1], "pull"), nil)
	assert.eq(#unplacedOf(doc), 1)
end)

test.case("apply keeps the recorded unplaced list when the authored list wasn't fetched", function(assert)
	local doc, fetched = stackFixture()
	fetched.authored = nil
	doc.github = json.object({
		viewer = "vocksel",
		unplaced = { json.object({ repo = "vocksel/orion", number = 9, title = "Unplaced", updatedAt = "now" }) },
	})
	applyPulls(doc, fetched, "later")
	local recorded = json.asObject(doc.github)
	local unplaced = if recorded then json.asArray(recorded.unplaced) else nil
	assert.eq(unplaced and #unplaced, 1)
	assert.eq(recorded and recorded.checkedAt, "later")
end)
