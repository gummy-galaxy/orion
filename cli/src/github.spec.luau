local test = require("@std/test")

local github = require("@root/github")
local testing = require("@root/testing")

type PullState = github.PullState

local function pull(
	state: string,
	extra: { draft: boolean?, reviewDecision: string?, reviewRequests: number? }?
): PullState
	local given = extra or {}
	return {
		owner = "flipbook-labs",
		name = "flipbook",
		number = 1,
		state = state,
		draft = given.draft == true,
		reviewDecision = given.reviewDecision,
		reviewRequests = given.reviewRequests or 0,
		title = "Title",
		url = "https://github.com/flipbook-labs/flipbook/pull/1",
	}
end

test.case("desired follows the pull request's state", function(assert)
	assert.eq(github.desired(pull("MERGED"), "review", "review"), "done")
	assert.eq(github.desired(pull("CLOSED"), "active", "you"), "deferred")
	assert.eq(github.desired(pull("OPEN", { draft = true }), "todo", nil), "active")
	local status, who = github.desired(pull("OPEN", { reviewRequests = 1 }), "active", "you")
	assert.eq(status, "review")
	assert.eq(who, "review")
	status, who = github.desired(pull("OPEN", { reviewDecision = "CHANGES_REQUESTED" }), "review", "review")
	assert.eq(status, "active")
	assert.eq(who, "you")
	status, who = github.desired(pull("OPEN", { reviewDecision = "APPROVED" }), "review", "review")
	assert.eq(status, "review")
	assert.eq(who, "you")
end)

test.case("desired keeps hand-set holds while the pull request is open", function(assert)
	assert.eq(github.desired(pull("OPEN", { reviewRequests = 1 }), "blocked", nil), "blocked")
	assert.eq(github.desired(pull("OPEN"), "deferred", nil), "deferred")
	assert.eq(github.desired(pull("MERGED"), "blocked", nil), "done")
end)

test.case("refFor reads bare and owner-qualified repositories", function(assert)
	local bare = github.refFor(testing.task("a", "A", "todo", nil, { repo = "flipbook", pr = 5 }), "flipbook-labs")
	assert.eq(bare and github.key(bare), "flipbook-labs/flipbook#5")
	local qualified =
		github.refFor(testing.task("b", "B", "todo", nil, { repo = "vocksel/orion", pr = 2 }), "flipbook-labs")
	assert.eq(qualified and github.key(qualified), "vocksel/orion#2")
	assert.eq(github.refFor(testing.task("c", "C", "todo"), "flipbook-labs"), nil)
end)

test.case("fetch batches pull requests into one GraphQL query", function(assert)
	local calls = 0
	local query = ""
	local found = github.fetch(function(argv)
		calls += 1
		query = argv[5]
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health","url":"u","state":"OPEN","isDraft":false,"reviewDecision":"REVIEW_REQUIRED","reviewRequests":{"totalCount":2}}},"p2":{"pullRequest":null}}}]]
		)
	end, {
		{ owner = "flipbook-labs", name = "flipbook", number = 658 },
		{ owner = "flipbook-labs", name = "flipbook", number = 9999 },
	})
	assert.eq(calls, 1)
	assert.strContains(query, "pullRequest(number: 658)")
	local hit = found["flipbook-labs/flipbook#658"]
	assert.eq(hit and hit.reviewRequests, 2)
	assert.eq(found["flipbook-labs/flipbook#9999"], nil)
end)

test.case("fetch rejects repository names that would break the query", function(assert)
	assert.throws(function()
		github.fetch(function()
			return testing.result(true, "{}")
		end, { { owner = 'x") { evil }', name = "y", number = 1 } })
	end)
end)

test.case("apply updates statuses, reports what's missing, and files new pull requests in an Inbox", function(assert)
	local doc = testing.doc({
		testing.task("a", "Mine", "active", nil, { repo = "flipbook", pr = 1, who = "you" }),
		testing.task("b", "Gone", "todo", nil, { repo = "flipbook", pr = 2 }),
	})
	local merged = pull("MERGED")
	local report = github.apply(doc, {
		pulls = { ["flipbook-labs/flipbook#1"] = merged },
		authored = {
			{
				owner = "flipbook-labs",
				name = "storyteller",
				number = 7,
				state = "OPEN",
				draft = true,
				reviewRequests = 0,
				title = "New work",
				url = "u",
			},
		},
	}, "2026-10-04T00:00:00Z")
	assert.eq(#report.changes, 1)
	assert.eq(report.changes[1].toStatus, "done")
	assert.eq(report.missing[1], "b")
	assert.eq(report.added[1], "storyteller-7")
	assert.eq(doc.nodes[3].id, "inbox")
	assert.eq(doc.nodes[4].parentId, "inbox")
	assert.eq(doc.nodes[4].data.status, "active")
end)
