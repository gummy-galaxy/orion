local json = require("@std/json")
local test = require("@std/test")

local collectSourcesAsync = require("@root/ingest/collectSourcesAsync")
local decodeDoc = require("@root/store/decodeDoc")
local encodeDoc = require("@root/store/encodeDoc")
local findRef = require("@root/refs/findRef")
local loadDoc = require("@root/store/loadDoc")
local placeRecords = require("@root/ingest/placeRecords")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

local NOW = "2026-10-04T00:00:00Z"

-- The commands this machine runs for the sources these tests configure. Hop sources run `hop` without one.
local COMMANDS = {
	jira = { "acli", "jira", "workitem", "search", "--json" },
	["jira-one"] = { "acli", "one" },
	["jira-two"] = { "acli", "two" },
}

local function runGh(argv: { string })
	local query = argv[#argv]

	if query:find("viewer { login }", 1, true) then
		return testing.result(true, [[{"data":{"viewer":{"login":"vocksel"}}}]])
	end

	if query:find("is:open is:issue", 1, true) then
		return testing.result(
			true,
			[[{"data":{"search":{"nodes":[{"number":14,"title":"Fix avatar loading","url":"https://github.com/Roblox/avatar/issues/14","repository":{"name":"avatar","owner":{"login":"Roblox"}}}],"pageInfo":{"hasNextPage":false}}}}]]
		)
	end

	if query:find("is:open is:pr", 1, true) then
		return testing.result(
			true,
			[[{"data":{"search":{"nodes":[{"number":20,"title":"Fix ABC-123 and closes #14","body":"Fixes Roblox/avatar#14","url":"https://github.com/Roblox/avatar/pull/20","state":"OPEN","isDraft":false,"headRefName":"ABC-123-avatar-fix","author":{"login":"vocksel"},"repository":{"name":"avatar","owner":{"login":"Roblox"}}}],"pageInfo":{"hasNextPage":false}}}}]]
		)
	end

	return testing.result(true, [[{"data":{"search":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}]])
end

test.case("GitHub and Jira ingest dedupe cards and mention links on re-ingest", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = {
		{ id = "gh-roblox", kind = "github", host = "github.com", owners = { "Roblox" } },
		{
			id = "jira",
			kind = "jira",
			browse = "https://jira.example.com/browse",
		},
	}

	local function runCommand(argv: { string })
		if argv[1] == "gh" then
			return runGh(argv)
		end

		return testing.result(
			true,
			[[{"issues":[{"key":"ABC-123","fields":{"summary":"Avatar loading","status":{"name":"In Progress","statusCategory":{"key":"indeterminate"}},"issuetype":{"name":"Story"},"epic":{"key":"ABC-1","summary":"Avatar"},"updated":"2026-10-03T00:00:00Z"}}]}]]
		)
	end

	local first = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runCommand, NOW))
	assert.eq(first.sources[1].added, 2)
	assert.eq(first.sources[1].linked, 2)
	assert.eq(first.sources[2].added, 1)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].origin, "mention")
	local dir = testing.directory("mention-links")
	writeDoc(dir, doc)
	assert.eq(loadDoc(dir).links[1].origin, "mention")
	assert.eq(doc.nodes[1].id, "unsorted")
	assert.eq(doc.nodes[1].data.layout, "refit")
	local count = #doc.nodes
	local second = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runCommand, NOW))
	assert.eq(#doc.nodes, count)
	assert.eq(#doc.links, 2)
	assert.eq(second.sources[1].updated, 2)
	local external = findRef(doc.nodes[4], "issue", "ABC-123")
	local details = if external then external.details else nil
	assert.eq(external and external.source, "jira")
	assert.eq(external and external.key, "ABC-123")
	assert.eq(external and external.url, "https://jira.example.com/browse/ABC-123")
	assert.eq(external and external.status, "In Progress")
	assert.eq(external and external.isDone, false)
	assert.eq(external and external.updatedAt, "2026-10-03T00:00:00Z")
	assert.eq(details and details.type, "Story")
	assert.eq(details and details.epicKey, "ABC-1")
	assert.eq(details and details.epicSummary, "Avatar")
	assert.eq(doc.nodes[4].data.status, "active")
end)

test.case("issue refs with the same key across sources identify one card", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = {
		{ id = "jira-one", kind = "jira" },
		{ id = "jira-two", kind = "jira" },
	}

	local function runCommand(argv: { string })
		local summary = if argv[2] == "one" then "First issue" else "Second issue"
		local category = if argv[2] == "one" then "new" else "done"
		return testing.result(
			true,
			string.format(
				'[{"key":"ABC-123","summary":"%s","status":"Done","statusCategory":"%s","type":"Task"}]',
				summary,
				category
			)
		)
	end

	local first = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runCommand, NOW))
	assert.eq(first.sources[1].added, 1)
	assert.eq(first.sources[2].updated, 1)
	assert.eq(#doc.nodes, 2)
	local issue = findRef(doc.nodes[2], "issue", "ABC-123")
	assert.eq(issue and issue.source, "jira-two")
	assert.eq(issue and issue.isDone, true)
	assert.eq(doc.nodes[2].data.status, "done")
	local second = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runCommand, NOW))
	assert.eq(second.sources[1].updated, 1)
	assert.eq(second.sources[2].updated, 1)
	assert.eq(#doc.nodes, 2)
	assert.eq(doc.nodes[2].data.label, "Second issue")
end)

test.case("hop step converts to a pull request without changing placement or note", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = { { id = "hop", kind = "hop" } }

	local function runHop(argv: { string })
		if argv[2] == "list" then
			return testing.result(
				true,
				[[{"worktrees":[{"branch":"feature/ABC-123-avatar-fix","onDefaultBranch":false,"lastActivity":1791072000,"repository":{"name":"Roblox/avatar","root":"/tmp/avatar"}}]}]]
			)
		end

		return testing.result(
			true,
			[=[[{"title":"Investigate avatar","repository":"Roblox/avatar","branch":"feature/ABC-123-avatar-fix","updatedAt":1791072000}]]=]
		)
	end

	placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runHop, NOW))
	local step = doc.nodes[2]
	assert.eq(step.data.itemKind, "step")
	assert.eq(step.data.label, "feature ABC-123 avatar fix")
	assert.eq(step.parentId, "unsorted")
	step.data.note = "Keep this note"
	local id = step.id
	doc.settings.sources = { { id = "gh-roblox", kind = "github", host = "github.com", owners = { "Roblox" } } }

	local function runCommand(argv: { string })
		local result = runGh(argv)

		if argv[#argv]:find("is:open is:pr", 1, true) then
			return testing.result(
				true,
				[[{"data":{"search":{"nodes":[{"number":20,"title":"Fix avatar","url":"u","state":"OPEN","isDraft":true,"headRefName":"feature/ABC-123-avatar-fix","author":{"login":"vocksel"},"repository":{"name":"avatar","owner":{"login":"Roblox"}}}],"pageInfo":{"hasNextPage":false}}}}]]
			)
		end

		return result
	end

	local report = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runCommand, NOW))
	assert.eq(report.sources[1].updated, 1)
	assert.eq(doc.nodes[2].id, id)
	assert.eq(doc.nodes[2].data.itemKind, "pr")
	assert.eq(doc.nodes[2].data.note, "Keep this note")
	assert.eq(doc.nodes[2].parentId, "unsorted")
end)

test.case("hop resolves bare repository names without changing case and matches later worktrees", function(assert)
	local doc = testing.createDoc({
		testing.task("pull", "Existing pull", "active", nil, {
			repo = "Roblox/Avatar",
			refs = { { source = "github", kind = "pull", key = "Roblox/Avatar#20" } },
		}),
	})
	doc.settings.sources = { { id = "hop-local", kind = "hop" } }

	local function runHop(argv: { string })
		if argv[2] == "list" then
			return testing.result(
				true,
				[[{"worktrees":[{"branch":"feature/new","onDefaultBranch":false,"lastActivity":1791072000,"repository":{"name":"Avatar"}}]}]]
			)
		end

		return testing.result(true, "[]")
	end

	local first = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runHop, NOW))
	assert.eq(first.sources[1].added, 1)
	local step = doc.nodes[3]
	assert.eq(step.data.repo, "Roblox/Avatar")
	assert.eq(step.data.itemKind, "step")
	assert.eq((findRef(step, "branch") :: any).key, "Roblox/Avatar@feature/new")

	local function runLowercaseHop(argv: { string })
		if argv[2] == "list" then
			return testing.result(
				true,
				[[{"worktrees":[{"branch":"feature/new","onDefaultBranch":false,"lastActivity":1791072000,"repository":{"name":"roblox/avatar"}}]}]]
			)
		end

		return testing.result(true, "[]")
	end

	local count = #doc.nodes
	local second = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runLowercaseHop, NOW))
	assert.eq(second.sources[1].updated, 1)
	assert.eq(#doc.nodes, count)
	assert.eq(step.data.repo, "Roblox/Avatar")
end)

test.case("one failed source does not stop other sources", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = {
		{ id = "hop", kind = "hop" },
		{ id = "jira", kind = "jira" },
	}
	local fetched = collectSourcesAsync(doc, COMMANDS, function(argv)
		if argv[1] == "hop" then
			return { ok = false, exitCode = 1, stdout = "", stderr = "not installed" }
		end

		return testing.result(
			true,
			[[[{"key":"ABC-2","summary":"Continue","status":"To Do","statusCategory":"new","type":"Task","updatedAt":"2026-10-03T00:00:00Z"}] ]]
		)
	end, NOW)
	local report = placeRecords(doc, fetched)
	assert.strContains(report.sources[1].failed or "", "not installed")
	assert.eq(report.sources[2].added, 1)
	assert.eq(#doc.nodes, 2)
end)

test.case("hop observes GitHub cards collected later in source configuration", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = {
		{ id = "hop", kind = "hop" },
		{ id = "gh-roblox", kind = "github", host = "github.com", owners = { "Roblox" } },
	}

	local function runCommand(argv: { string })
		if argv[1] == "gh" then
			return runGh(argv)
		elseif argv[2] == "list" then
			return testing.result(
				true,
				[[{"worktrees":[{"branch":"ABC-123-avatar-fix","onDefaultBranch":false,"lastActivity":1791072000,"repository":{"name":"avatar"}}]}]]
			)
		end

		return testing.result(true, "[]")
	end

	local report = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runCommand, NOW))
	assert.eq(report.sources[1].id, "hop")
	assert.eq(report.sources[1].updated, 1)
	assert.eq(report.sources[2].added, 2)
	assert.eq(#doc.nodes, 3)
	local branch = findRef(doc.nodes[2], "branch")
	assert.eq(branch and branch.key, "Roblox/avatar@ABC-123-avatar-fix")
end)

test.case("hop attaches worktree activity to pull cards", function(assert)
	local doc = decodeDoc(
		[[{"version":2,"settings":{"sources":[{"id":"gh-flipbook-labs","kind":"github","host":"github.com","owners":["flipbook-labs"]},{"id":"hop","kind":"hop"}]},"nodes":[{"id":"st-161","type":"task","position":{"x":24,"y":240},"data":{"label":"Batch matching discovery queries","status":"done","kind":"task","itemKind":"pr","repo":"flipbook-labs/storyteller","refs":[{"source":"github","kind":"pull","key":"flipbook-labs/storyteller#161","url":"https://github.com/flipbook-labs/storyteller/pull/161","status":"merged","isDone":true,"details":{"state":"MERGED","url":"https://github.com/flipbook-labs/storyteller/pull/161","branch":"batch-discovery-queries"}}]}},{"id":"st-162","type":"task","position":{"x":24,"y":150},"data":{"label":"Reference-count Storyteller consumers","status":"done","kind":"task","itemKind":"pr","repo":"flipbook-labs/storyteller","refs":[{"source":"github","kind":"pull","key":"flipbook-labs/storyteller#162","url":"https://github.com/flipbook-labs/storyteller/pull/162","status":"merged","isDone":true,"details":{"state":"MERGED","url":"https://github.com/flipbook-labs/storyteller/pull/162","branch":"reference-count-storyteller-runtime"}}]}}]}]]
	)
	for _, branch in { "batch-discovery-queries", "reference-count-storyteller-runtime" } do
		table.insert(
			doc.nodes,
			testing.task(`existing-{branch}`, "Existing branch", "active", nil, {
				repo = "flipbook-labs/storyteller",
				refs = { { source = "hop", kind = "branch", key = `flipbook-labs/storyteller@{branch}` } },
			})
		)
	end

	local list =
		[[{"worktrees":[{"repository":{"remote":"flipbook-labs/storyteller"},"branch":"batch-discovery-queries","onDefaultBranch":false,"lastActivity":1789941379.617885},{"repository":{"remote":"flipbook-labs/storyteller"},"branch":"reference-count-storyteller-runtime","onDefaultBranch":false,"lastActivity":1789940593.504069}]}]]
	local function runHop(argv: { string })
		return testing.result(true, if argv[2] == "list" then list else "[]")
	end

	local report = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runHop, "2026-10-09T01:30:00Z", "hop"))
	assert.eq(report.sources[1].updated, 2)

	doc = decodeDoc(encodeDoc(doc))

	for index = 1, 2 do
		local item = doc.nodes[index]
		local branch = findRef(item, "branch")
		assert.eq(branch and branch.source, "hop")
		assert.eq(branch and branch.key, `flipbook-labs/storyteller@{(findRef(item, "pull") :: any).details.branch}`)
		assert.eq(branch and branch.details and branch.details.sessions, {})
	end
end)

test.case("hop session activity follows the pull card before a duplicate branch ref", function(assert)
	local pull = testing.task("pull", "Pull", "done", nil, {
		repo = "flipbook-labs/storyteller",
		refs = {
			{
				source = "github",
				kind = "pull",
				key = "flipbook-labs/storyteller#161",
				details = json.object({ branch = "batch-discovery-queries" }),
			},
		},
	})
	local duplicate = testing.task("duplicate", "Branch", "active", nil, {
		repo = "flipbook-labs/storyteller",
		refs = { { source = "hop", kind = "branch", key = "flipbook-labs/storyteller@batch-discovery-queries" } },
	})
	local doc = testing.createDoc({ pull, duplicate })
	doc.settings.sources = { { id = "hop", kind = "hop" } }
	local function runHop(argv: { string })
		return testing.result(
			true,
			if argv[2] == "list"
				then [[{"worktrees":[]}]]
				else '[{"repository":"flipbook-labs/storyteller","branch":"batch-discovery-queries","title":"Review","updatedAt":1789941379}]'
		)
	end

	local report = placeRecords(doc, collectSourcesAsync(doc, COMMANDS, runHop, "2026-10-09T01:30:00Z"))
	assert.eq(report.sources[1].updated, 0)
	local branch = findRef(pull, "branch")
	assert.eq(branch and branch.details and branch.details.sessions, { "Review" })
	local duplicateBranch = findRef(duplicate, "branch")
	assert.eq(duplicateBranch and duplicateBranch.details, nil)
end)
