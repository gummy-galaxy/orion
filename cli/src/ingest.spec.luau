local json = require("@std/json")
local test = require("@std/test")

local ingest = require("@root/ingest")
local store = require("@root/store")
local testing = require("@root/testing")

local NOW = "2026-10-04T00:00:00Z"

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
			command = { "acli", "jira", "workitem", "search", "--json" },
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

	local first = ingest.apply(doc, ingest.collect(doc, runCommand, NOW), NOW)
	assert.eq(first.sources[1].added, 2)
	assert.eq(first.sources[1].linked, 2)
	assert.eq(first.sources[2].added, 1)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].origin, "mention")
	local directory = testing.directory("mention-links")
	store.write(directory, doc)
	assert.eq(store.load(directory).links[1].origin, "mention")
	assert.eq(doc.nodes[1].id, "unsorted")
	assert.eq(doc.nodes[1].data.layout, "refit")
	local count = #doc.nodes
	local second = ingest.apply(doc, ingest.collect(doc, runCommand, NOW), NOW)
	assert.eq(#doc.nodes, count)
	assert.eq(#doc.links, 2)
	assert.eq(second.sources[1].updated, 2)
	local external = json.asObject(doc.nodes[4].data.external)
	local details = if external then json.asObject(external.details) else nil
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

test.case("external cards with the same key in different sources stay separate", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = {
		{ id = "jira-one", kind = "jira", command = { "acli", "one" } },
		{ id = "jira-two", kind = "jira", command = { "acli", "two" } },
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

	local first = ingest.apply(doc, ingest.collect(doc, runCommand, NOW), NOW)
	assert.eq(first.sources[1].added, 1)
	assert.eq(first.sources[2].added, 1)
	assert.eq(#doc.nodes, 3)
	local one = json.asObject(doc.nodes[2].data.external)
	local two = json.asObject(doc.nodes[3].data.external)
	assert.eq(one and one.source, "jira-one")
	assert.eq(two and two.source, "jira-two")
	assert.eq(two and two.isDone, true)
	assert.eq(doc.nodes[3].data.status, "done")
	local second = ingest.apply(doc, ingest.collect(doc, runCommand, NOW), NOW)
	assert.eq(second.sources[1].updated, 1)
	assert.eq(second.sources[2].updated, 1)
	assert.eq(#doc.nodes, 3)
	assert.eq(doc.nodes[2].data.label, "First issue")
	assert.eq(doc.nodes[3].data.label, "Second issue")
end)

test.case("hop step converts to a pull request without changing placement or note", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = { { id = "hop", kind = "hop", command = { "hop" } } }

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

	ingest.apply(doc, ingest.collect(doc, runHop, NOW), NOW)
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

	local report = ingest.apply(doc, ingest.collect(doc, runCommand, NOW), NOW)
	assert.eq(report.sources[1].updated, 1)
	assert.eq(doc.nodes[2].id, id)
	assert.eq(doc.nodes[2].data.itemKind, "pr")
	assert.eq(doc.nodes[2].data.note, "Keep this note")
	assert.eq(doc.nodes[2].parentId, "unsorted")
end)

test.case("one failed source does not stop other sources", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = {
		{ id = "hop", kind = "hop", command = { "hop" } },
		{ id = "jira", kind = "jira", command = { "acli", "jira", "workitem", "search" } },
	}
	local fetched = ingest.collect(doc, function(argv)
		if argv[1] == "hop" then
			return { ok = false, exitCode = 1, stdout = "", stderr = "not installed" }
		end

		return testing.result(
			true,
			[[[{"key":"ABC-2","summary":"Continue","status":"To Do","statusCategory":"new","type":"Task","updatedAt":"2026-10-03T00:00:00Z"}] ]]
		)
	end, NOW)
	local report = ingest.apply(doc, fetched, NOW)
	assert.strContains(report.sources[1].failed or "", "not installed")
	assert.eq(report.sources[2].added, 1)
	assert.eq(#doc.nodes, 2)
end)
