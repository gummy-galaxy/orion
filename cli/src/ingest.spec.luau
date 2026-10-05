local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local ingest = require("@root/ingest")
local store = require("@root/store")
local testing = require("@root/testing")

local NOW = "2026-10-04T00:00:00Z"

local function ghRunner(argv: { string })
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
	local doc = testing.doc({})
	doc.settings.sources = {
		{ id = "gh-roblox", kind = "github", host = "github.com", owners = { "Roblox" } },
		{
			id = "jira",
			kind = "jira",
			command = { "acli", "jira", "workitem", "search", "--json" },
			browse = "https://jira.example.com/browse",
		},
	}
	local function runner(argv: { string })
		if argv[1] == "gh" then
			return ghRunner(argv)
		end
		return testing.result(
			true,
			[[{"issues":[{"key":"ABC-123","fields":{"summary":"Avatar loading","status":{"name":"In Progress","statusCategory":{"key":"indeterminate"}},"issuetype":{"name":"Story"},"epic":{"key":"ABC-1","summary":"Avatar"},"updated":"2026-10-03T00:00:00Z"}}]}]]
		)
	end
	local first = ingest.apply(doc, ingest.collect(doc, runner, NOW), NOW)
	assert.eq(first.sources[1].added, 2)
	assert.eq(first.sources[1].linked, 2)
	assert.eq(first.sources[2].added, 1)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].origin, "mention")
	local dir = testing.directory("mention-links")
	store.write(dir, doc)
	assert.eq(store.load(dir).links[1].origin, "mention")
	assert.eq(doc.nodes[1].id, "unsorted")
	assert.eq(doc.nodes[1].data.layout, "refit")
	local count = #doc.nodes
	local second = ingest.apply(doc, ingest.collect(doc, runner, NOW), NOW)
	assert.eq(#doc.nodes, count)
	assert.eq(#doc.links, 2)
	assert.eq(second.sources[1].updated, 2)
	local jira = json.asObject(doc.nodes[4].data.jira)
	assert.eq(jira and jira.epicKey, "ABC-1")
	assert.eq(jira and jira.statusCategory, "indeterminate")
	assert.eq(doc.nodes[4].data.status, "active")
end)

test.case("hop step converts to a pull request without changing placement or note", function(assert)
	local doc = testing.doc({})
	doc.settings.sources = { { id = "hop", kind = "hop", command = { "hop" } } }
	local function hopRunner(argv: { string })
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
	ingest.apply(doc, ingest.collect(doc, hopRunner, NOW), NOW)
	local step = doc.nodes[2]
	assert.eq(step.data.itemKind, "step")
	assert.eq(step.data.label, "feature ABC-123 avatar fix")
	assert.eq(step.parentId, "unsorted")
	step.data.note = "Keep this note"
	local id = step.id
	doc.settings.sources = { { id = "gh-roblox", kind = "github", host = "github.com", owners = { "Roblox" } } }
	local function runner(argv: { string })
		local result = ghRunner(argv)
		if argv[#argv]:find("is:open is:pr", 1, true) then
			return testing.result(
				true,
				[[{"data":{"search":{"nodes":[{"number":20,"title":"Fix avatar","url":"u","state":"OPEN","isDraft":true,"headRefName":"feature/ABC-123-avatar-fix","author":{"login":"vocksel"},"repository":{"name":"avatar","owner":{"login":"Roblox"}}}],"pageInfo":{"hasNextPage":false}}}}]]
			)
		end
		return result
	end
	local report = ingest.apply(doc, ingest.collect(doc, runner, NOW), NOW)
	assert.eq(report.sources[1].updated, 1)
	assert.eq(doc.nodes[2].id, id)
	assert.eq(doc.nodes[2].data.itemKind, "pr")
	assert.eq(doc.nodes[2].data.note, "Keep this note")
	assert.eq(doc.nodes[2].parentId, "unsorted")
end)

test.case("one failed source does not stop other sources", function(assert)
	local doc = testing.doc({})
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

test.case("source commands validate and persist configuration", function(assert)
	local dir = testing.directory("sources")
	store.write(dir, testing.doc({}))
	local function run(args: { string }): string
		local lines = {}
		cli.execute(args, {
			dataDir = dir,
			write = function(line)
				table.insert(lines, line)
			end,
		})
		return table.concat(lines, "\n")
	end
	run({
		"source",
		"add",
		"github",
		"--host",
		"github.com",
		"--owner",
		"Roblox",
		"--owner",
		"Example",
		"--include",
		"avatar",
	})
	run({ "source", "add", "jira", "--command", [[ ["acli","jira","workitem","search","--json"] ]] })
	run({ "source", "add", "hop" })
	local values = json.asArray(json.deserialize(run({ "source", "list", "--json" })) :: json.Value)
	assert.eq(values and #values, 3)
	assert.eq(store.load(dir).settings.sources[1].owners, { "Roblox", "Example" })
	assert.throws(function()
		run({ "source", "add", "github", "--host", "evil/@host", "--owner", "Roblox" })
	end)
	run({ "source", "remove", "hop" })
	assert.eq(#store.load(dir).settings.sources, 2)
end)

test.case("ingest dry run reports changes without writing", function(assert)
	local dir = testing.directory("ingest-dry-run")
	local doc = testing.doc({})
	doc.settings.sources = { { id = "jira", kind = "jira", command = { "acli", "jira", "workitem", "search" } } }
	store.write(dir, doc)
	local function run(args: { string }): string
		local output = ""
		cli.execute(args, {
			dataDir = dir,
			now = function()
				return NOW
			end,
			write = function(line)
				output = line
			end,
			runner = function()
				return testing.result(
					true,
					[[ [{"key":"ABC-9","summary":"Ship","statusCategory":"new","type":"Task"}] ]]
				)
			end,
		})
		return output
	end
	local report = json.asObject(json.deserialize(run({ "ingest", "--dry-run", "--json" })) :: json.Value)
	local sources = if report then json.asArray(report.sources) else nil
	local first = if sources then json.asObject(sources[1]) else nil
	assert.eq(first and first.added, 1)
	assert.eq(store.load(dir).revision, 0)
	run({ "ingest" })
	assert.eq(store.load(dir).revision, 1)
	assert.eq(#store.load(dir).nodes, 2)
end)
