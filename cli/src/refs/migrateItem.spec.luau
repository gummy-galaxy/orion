local json = require("@std/json")
local test = require("@std/test")

local findRef = require("@root/refs/findRef")
local getRefs = require("@root/refs/getRefs")
local migrateItem = require("@root/refs/migrateItem")
local testing = require("@root/testing")

test.case("migrateItem converts legacy fields once", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		repo = "orion",
		pr = 12,
		branch = "feature/A",
		github = json.object({ state = "OPEN", draft = true, updatedAt = "now" }),
		activity = json.object({ sessions = { "Work" } }),
		sources = { "hop-local" },
	})
	migrateItem(item, "vocksel", { { id = "hop-local", kind = "hop" } })
	assert.eq(item.data.repo, "vocksel/orion")
	assert.eq(item.data.itemKind, "pr")
	assert.eq(getRefs(item)[1].key, "vocksel/orion#12")
	assert.eq(getRefs(item)[1].status, "draft")
	assert.eq(getRefs(item)[2].source, "hop-local")
	assert.eq(item.data.pr, nil)
	migrateItem(item, "vocksel", {})
	assert.eq(#getRefs(item), 2)
end)

test.case("migrateItem keeps a repo-only GitHub pull association", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		sources = { json.object({ kind = "github-pr", repo = "orion" }) },
	})
	migrateItem(item, "vocksel", {})
	assert.eq(item.data.repo, "vocksel/orion")
	assert.eq(item.data.itemKind, "step")
	assert.eq(#getRefs(item), 0)
	assert.eq(item.data.sources, nil)
end)

test.case("migrateItem gives a card that lost its pull request a kind from its repository", function(assert)
	local item = testing.task("a", "A", "todo", nil, { itemKind = "pr", repo = "vocksel/orion" })
	migrateItem(item, "vocksel", {})
	assert.eq(item.data.itemKind, "placeholder")
end)

test.case("migrateItem records a typed GitHub pull with source state and branch", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		sources = {
			json.object({
				kind = "github-pr",
				repo = "vocksel/orion",
				number = 37,
				branch = "agent/sticker-wheel",
				via = "gh-vocksel",
				state = json.object({
					state = "MERGED",
					draft = false,
					url = "https://github.com/vocksel/orion/pull/37",
					updatedAt = "2026-10-04T00:00:00Z",
					mergeStateStatus = "UNKNOWN",
				}),
			}),
		},
	})
	migrateItem(item, "flipbook-labs", {})
	local pull = findRef(item, "pull")
	assert.eq(item.data.repo, "vocksel/orion")
	assert.eq(item.data.itemKind, "pr")
	assert.eq(pull and pull.source, "gh-vocksel")
	assert.eq(pull and pull.key, "vocksel/orion#37")
	assert.eq(pull and pull.url, "https://github.com/vocksel/orion/pull/37")
	assert.eq(pull and pull.status, "merged")
	assert.eq(pull and pull.isDone, true)
	assert.eq(pull and pull.updatedAt, "2026-10-04T00:00:00Z")
	assert.eq(pull and pull.details and pull.details.branch, "agent/sticker-wheel")
	assert.eq(pull and pull.details and pull.details.mergeStateStatus, "UNKNOWN")
	local withoutVia = testing.task("b", "B", "todo", nil, {
		sources = { json.object({ kind = "github-pr", repo = "orion", number = 38 }) },
	})
	migrateItem(withoutVia, "vocksel", {})
	local otherPull = findRef(withoutVia, "pull")
	assert.eq(otherPull and otherPull.source, "github")
	assert.eq(otherPull and otherPull.url, "https://github.com/vocksel/orion/pull/38")
end)

test.case("migrateItem records a typed GitHub issue", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		sources = { json.object({ kind = "github-issue", repo = "flipbook", number = 621, via = "gh-flipbook-labs" }) },
	})
	migrateItem(item, "flipbook-labs", {})
	local issue = findRef(item, "issue")
	assert.eq(item.data.repo, "flipbook-labs/flipbook")
	assert.eq(issue and issue.source, "gh-flipbook-labs")
	assert.eq(issue and issue.key, "flipbook-labs/flipbook#621")
	assert.eq(issue and issue.url, "https://github.com/flipbook-labs/flipbook/issues/621")
	local withoutVia = testing.task("b", "B", "todo", nil, {
		sources = { json.object({ kind = "github-issue", repo = "flipbook", number = 622 }) },
	})
	migrateItem(withoutVia, "flipbook-labs", {})
	assert.eq((findRef(withoutVia, "issue") :: any).source, "github")
end)

test.case("migrateItem records typed hop activity", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		sources = {
			json.object({
				kind = "hop",
				repo = "changewrite",
				branch = "release-branch-config",
				via = "hop-local",
				state = json.object({ sessions = {}, lastActiveAt = "2026-10-04T02:32:28Z" }),
			}),
		},
	})
	migrateItem(item, "flipbook-labs", {})
	local branch = findRef(item, "branch")
	assert.eq(item.data.repo, "flipbook-labs/changewrite")
	assert.eq(branch and branch.source, "hop-local")
	assert.eq(branch and branch.key, "flipbook-labs/changewrite@release-branch-config")
	assert.eq(branch and branch.details and branch.details.lastActiveAt, "2026-10-04T02:32:28Z")
end)

test.case("migrateItem merges mixed string and typed sources with top-level refs", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		repo = "orion",
		pr = 37,
		github = json.object({ state = "OPEN", url = "https://github.com/vocksel/orion/pull/37" }),
		branch = "feature/A",
		activity = json.object({ sessions = { "Old" } }),
		sources = {
			"hop-local",
			json.object({
				kind = "github-pr",
				repo = "orion",
				number = 37,
				via = "gh-vocksel",
				state = json.object({ state = "MERGED" }),
			}),
			json.object({
				kind = "hop",
				repo = "orion",
				branch = "feature/A",
				state = json.object({ sessions = { "New" } }),
			}),
		},
	})
	migrateItem(item, "vocksel", { { id = "hop-local", kind = "hop" } })
	local pull = findRef(item, "pull")
	local branch = findRef(item, "branch")
	assert.eq(#getRefs(item), 2)
	assert.eq(pull and pull.source, "gh-vocksel")
	assert.eq(pull and pull.status, "merged")
	assert.eq(pull and pull.url, "https://github.com/vocksel/orion/pull/37")
	assert.eq(branch and branch.source, "hop-local")
	local sessions = if branch and branch.details then json.asArray(branch.details.sessions) else nil
	assert.eq(sessions and sessions[1], "New")
	assert.eq(item.data.sources, nil)
end)
