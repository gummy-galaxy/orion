local cli = require("@root/cli")
local json = require("@std/json")
local test = require("@std/test")

local loadDoc = require("@root/storage/canvases/loadDoc")
local setSourceCommand = require("@root/sources/setSourceCommand")
local testing = require("@root/testing")
local types = require("@root/types")
local writeDoc = require("@root/storage/canvases/writeDoc")

type Source = types.Source

local NOW = "2026-10-04T00:00:00Z"
local ISSUE_URL = "https://github.com/vocksel/orion/issues/91"
local PULL_URL = "https://github.com/vocksel/orion/pull/251"
local JIRA: Source = {
	id = "jira",
	kind = "jira",
	browse = "https://jira.example.com/browse",
}

local function githubRunner(argv: { string }): types.CommandResult
	local query = argv[#argv]
	if query:find("pullRequest(number: 251)", 1, true) then
		return testing.result(
			true,
			'{"data": {"p1": {"pullRequest": {"title": "Add --ref",'
				.. ' "url": "https://github.com/vocksel/orion/pull/251"}}}}'
		)
	end
	return testing.result(
		true,
		'{"data": {"p1": {"issue": {"title": "Import a list of sources",'
			.. ' "url": "https://github.com/vocksel/orion/issues/91"}}}}'
	)
end

local function unreachableRunner(): types.CommandResult
	error("no lookup should run")
end

-- Runs the command expecting it to fail; returns whether it succeeded and the
-- failure text.
local function runFailing(dir: string, args: { string }, runner: types.CommandRunner): (boolean, string)
	local ok, failure = pcall(function()
		testing.run(dir, args, runner, NOW)
	end)
	return ok, tostring(failure)
end

local function parseJson(output: string): json.Object
	return assert(json.asObject(json.deserialize(output) :: json.Value))
end

test.case("an issue URL adds a card with its GitHub title, repo, and ref", function(assert)
	local dir = testing.directory("import-issue")
	writeDoc(dir, testing.createDoc({}))

	local report = parseJson(testing.run(dir, { "card", "import", ISSUE_URL, "--json" }, githubRunner, NOW))
	assert.eq(report.added, 1)
	assert.eq(report.failed, 0)
	assert.eq(report.revision, 1)

	local doc = loadDoc(dir)
	assert.eq(#doc.nodes, 1)
	local item = doc.nodes[1]
	assert.eq(item.data.label, "Import a list of sources")
	assert.eq(item.data.repo, "vocksel/orion")
	assert.eq(item.data.itemKind, "placeholder")
	assert.eq(item.data.who, "you")
	local refs = item.data.refs :: { json.Object }
	assert.eq(refs[1].kind, "issue")
	assert.eq(refs[1].key, "vocksel/orion#91")
	assert.eq(refs[1].url, ISSUE_URL)
end)

test.case("a pull request URL adds a pull request card", function(assert)
	local dir = testing.directory("import-pull")
	writeDoc(dir, testing.createDoc({}))

	testing.run(dir, { "card", "import", PULL_URL }, githubRunner, NOW)

	local item = loadDoc(dir).nodes[1]
	assert.eq(item.data.label, "Add --ref")
	assert.eq(item.data.itemKind, "pr")
	assert.eq(item.data.who, nil)
end)

test.case("a ref already on the canvas is skipped without a lookup or a second card", function(assert)
	local dir = testing.directory("import-existing")
	local doc = testing.createDoc({
		testing.task("kept", "Already tracked", "todo", nil, {
			refs = { { source = "github", kind = "issue", key = "vocksel/orion#91", url = ISSUE_URL } },
		}),
	})
	writeDoc(dir, doc)

	local report = parseJson(testing.run(dir, { "card", "import", ISSUE_URL, "--json" }, unreachableRunner, NOW))
	assert.eq(report.existing, 1)
	assert.eq(report.added, 0)
	assert.eq(report.revision, 0)
	assert.eq(#loadDoc(dir).nodes, 1)
end)

test.case("a bad ref or a missing one is reported, the rest are added, and the command fails", function(assert)
	local dir = testing.directory("import-partial")
	writeDoc(dir, testing.createDoc({}))

	local ok, failure = runFailing(
		dir,
		{ "card", "import", ISSUE_URL, "https://git.example.org/Roblox/avatar/pull/1", "jira:ABC-9", "--json" },
		githubRunner
	)

	assert.eq(ok, false)
	assert.strContains(failure, "2 of 3 refs could not be imported")
	local doc = loadDoc(dir)
	assert.eq(#doc.nodes, 1)
	assert.eq(doc.revision, 1)
end)

test.case("a failed ref still prints every outcome before the command fails", function(assert)
	local dir = testing.directory("import-report")
	writeDoc(dir, testing.createDoc({}))

	local printed: { string } = {}
	local ok = pcall(function()
		cli.execute({ "card", "import", ISSUE_URL, "https://git.example.org/Roblox/avatar/pull/1" }, {
			dataDir = dir,
			write = function(line)
				table.insert(printed, line)
			end,
			runner = githubRunner,
			now = function()
				return NOW
			end,
		})
	end)

	local output = table.concat(printed, "\n")
	assert.eq(ok, false)
	assert.strContains(output, "Added 1 card, 1 failed at revision 0 → 1")
	assert.strContains(output, "added")
	assert.strContains(output, "failed")
	assert.strContains(output, "no source recognizes https://git.example.org/Roblox/avatar/pull/1")
end)

test.case("--group puts the new card inside the group", function(assert)
	local dir = testing.directory("import-group")
	writeDoc(dir, testing.createDoc({ testing.group("ws", "Release") }))

	testing.run(dir, { "card", "import", ISSUE_URL, "--group", "ws" }, githubRunner, NOW)

	assert.eq(loadDoc(dir).nodes[2].parentId, "ws")
end)

test.case("--group must name a group", function(assert)
	local dir = testing.directory("import-bad-group")
	writeDoc(dir, testing.createDoc({ testing.task("one", "Item", "todo") }))

	local ok, failure = runFailing(dir, { "card", "import", ISSUE_URL, "--group", "one" }, githubRunner)
	assert.eq(ok, false)
	assert.strContains(failure, "is an item, not a group")
	assert.eq(loadDoc(dir).revision, 0)
end)

test.case("--dry-run previews cards and writes nothing", function(assert)
	local dir = testing.directory("import-dry-run")
	writeDoc(dir, testing.createDoc({}))

	local output = testing.run(dir, { "card", "import", ISSUE_URL, "--dry-run" }, githubRunner, NOW)

	assert.strContains(output, "Would add 1 card")
	assert.strContains(output, "at revision 0")
	assert.eq(loadDoc(dir).revision, 0)
	assert.eq(#loadDoc(dir).nodes, 0)
end)

test.case("--if-revision refuses the write when the document has moved", function(assert)
	local dir = testing.directory("import-if-revision")
	writeDoc(dir, testing.createDoc({}))

	local ok, failure = runFailing(dir, { "card", "import", ISSUE_URL, "--if-revision", "5" }, githubRunner)
	assert.eq(ok, false)
	assert.strContains(failure, "revision changed: expected 5, current 0")
	assert.eq(#loadDoc(dir).nodes, 0)
end)

test.case("a configured Jira source imports a key from its results", function(assert)
	local dir = testing.directory("import-jira")
	local doc = testing.createDoc({})
	doc.settings.sources = { JIRA }
	writeDoc(dir, doc)
	setSourceCommand(dir, "default", "jira", { "acli", "jira", "workitem", "search" })

	local output = testing.run(dir, { "card", "import", "jira:ABC-9", "--json" }, function(argv)
		assert.eq(argv[1], "acli")
		return testing.result(true, '[{"key":"ABC-9","summary":"Ship","statusCategory":"new","type":"Task"}]')
	end, NOW)

	assert.eq(parseJson(output).added, 1)
	local item = loadDoc(dir).nodes[1]
	assert.eq(item.data.label, "Ship")
	assert.eq(item.data.status, "todo")
	assert.eq(item.data.who, "you")
	local refs = item.data.refs :: { json.Object }
	assert.eq(refs[1].source, "jira")
	assert.eq(refs[1].key, "ABC-9")
end)

test.case("a Jira key missing from the source's results fails with that reason", function(assert)
	local dir = testing.directory("import-jira-missing")
	local doc = testing.createDoc({})
	doc.settings.sources = { JIRA }
	writeDoc(dir, doc)
	setSourceCommand(dir, "default", "jira", { "acli", "jira", "workitem", "search" })

	local ok, failure = runFailing(dir, { "card", "import", "jira:ABC-9" }, function()
		return testing.result(true, "[]")
	end)

	assert.eq(ok, false)
	assert.strContains(failure, "1 of 1 refs could not be imported")
	assert.eq(#loadDoc(dir).nodes, 0)
end)

test.case("a Jira source with no command on this machine says how to set one", function(assert)
	local dir = testing.directory("import-jira-no-command")
	local doc = testing.createDoc({})
	doc.settings.sources = { JIRA }
	writeDoc(dir, doc)

	local ok, failure = runFailing(dir, { "card", "import", "jira:ABC-9", "--json" }, unreachableRunner)

	assert.eq(ok, false)
	assert.strContains(failure, "1 of 1 refs could not be imported")
	assert.eq(#loadDoc(dir).nodes, 0)
end)
