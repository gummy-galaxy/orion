local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local graph = require("@root/graph")
local store = require("@root/store")
local suggest = require("@root/suggest")
local testing = require("@root/testing")
local types = require("@root/types")

local function unexpectedRunner(_argv: { string }, _stdin: string?): types.CommandResult
	error("unexpected agent call")
end

local function compute(doc: types.Doc, agent: string?, runner: types.CommandRunner?, scope: string?)
	return suggest.compute(
		doc,
		scope or "unsorted",
		agent or "none",
		runner or unexpectedRunner,
		"2026-10-04T00:00:00Z"
	)
end

local function pair(extraA: json.Object?, extraB: json.Object?)
	return testing.doc({
		testing.task("a", "First work", "todo", nil, extraA),
		testing.task("b", "Second work", "todo", nil, extraB),
	})
end

test.case("heuristics join linked cards", function(assert)
	local doc = pair()
	graph.link(doc, "a", "b", "related")
	local result = compute(doc)
	assert.eq(#result.groups, 1)
	assert.eq(result.groups[1].reason, "Linked work")
end)

test.case("heuristics join a shared Jira epic", function(assert)
	local doc = pair(
		json.object({ jira = json.object({ key = "ABC-2", epicKey = "ABC-1", epicSummary = "Avatar loading" }) }),
		json.object({ jira = json.object({ key = "ABC-3", epicKey = "ABC-1" }) })
	)
	local result = compute(doc)
	assert.eq(result.groups[1].title, "Avatar loading")
	assert.eq(result.groups[1].reason, "Shared epic ABC-1")
end)

test.case("heuristics join the same repository branch", function(assert)
	local doc = pair(
		json.object({ repo = "app", branch = "agent/avatar" }),
		json.object({ repo = "app", branch = "agent/avatar" })
	)
	table.insert(
		doc.nodes,
		testing.task(
			"c",
			"Other work",
			"todo",
			nil,
			json.object({ host = "github.example.com", repo = "app", branch = "agent/avatar" })
		)
	)
	local result = compute(doc)
	assert.eq(#result.groups, 1)
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
	assert.eq(result.groups[1].reason, "Shared branch agent/avatar")
end)

test.case("heuristics join issue references in titles and branches", function(assert)
	local doc = testing.doc({
		testing.task("a", "Issue #123", "todo", nil, json.object({ repo = "app", issue = 123 })),
		testing.task("b", "Build view", "todo", nil, json.object({ repo = "app", branch = "fix-#123" })),
		testing.task("c", "ABC-9 migration", "todo"),
		testing.task("d", "Migrate data", "todo", nil, json.object({ repo = "data", branch = "work/ABC-9" })),
	})
	local result = compute(doc)
	assert.eq(#result.groups, 2)
	assert.eq(result.groups[1].reason, "Shared Jira or issue reference")
	assert.eq(result.groups[2].reason, "Shared Jira or issue reference")
end)

test.case("title overlap joins only a matching repository without epic conflict", function(assert)
	local doc = testing.doc({
		testing.task("a", "Improve avatar loading", "todo", nil, json.object({ repo = "app" })),
		testing.task("b", "Fix avatar loading", "todo", nil, json.object({ repo = "app" })),
		testing.task("c", "Fix avatar loading", "todo", nil, json.object({ repo = "other" })),
	})
	local result = compute(doc)
	assert.eq(#result.groups, 1)
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
	assert.eq(result.groups[1].reason, "Strong title overlap")

	local conflicting = testing.doc({
		testing.task(
			"a",
			"Improve avatar loading",
			"todo",
			nil,
			json.object({ repo = "app", jira = json.object({ key = "ABC-3", epicKey = "ABC-1" }) })
		),
		testing.task(
			"b",
			"Fix avatar loading",
			"todo",
			nil,
			json.object({ repo = "app", jira = json.object({ key = "ABC-4", epicKey = "ABC-2" }) })
		),
	})
	assert.eq(#compute(conflicting).groups, 0)
end)

test.case("default scope includes unsorted and top-level cards, ignoring notes", function(assert)
	local doc = testing.doc({
		testing.group("unsorted", "Unsorted"),
		testing.group("placed", "Placed"),
		testing.task("a", "Alpha loading", "todo", "unsorted", json.object({ repo = "app" })),
		testing.task("b", "Alpha loading", "todo", nil, json.object({ repo = "app" })),
		testing.task("c", "Alpha loading", "todo", "placed", json.object({ repo = "app" })),
		testing.task("note", "Alpha loading", "todo", nil, json.object({ itemKind = "note", repo = "app" })),
	})
	assert.eq(table.concat(compute(doc).groups[1].members, ","), "a,b")
	assert.eq(table.concat(compute(doc, nil, nil, "all").groups[1].members, ","), "a,b,c")
end)

test.case("agent reply drops unknown and duplicate ids while retaining ignored heuristics", function(assert)
	local doc = testing.doc({
		testing.task("a", "Avatar one", "todo", nil, json.object({ repo = "app", branch = "avatar" })),
		testing.task("b", "Avatar two", "todo", nil, json.object({ repo = "app", branch = "avatar" })),
		testing.task("c", "Color one", "todo", nil, json.object({ repo = "app", branch = "color" })),
		testing.task("d", "Color two", "todo", nil, json.object({ repo = "app", branch = "color" })),
	})
	local prompt = ""
	local result, fallback = compute(doc, "claude", function(argv, stdin)
		assert.eq(argv[1], "claude")
		prompt = stdin
		return testing.result(
			true,
			[[{"result":"{\"groups\":[{\"title\":\"Avatar work\",\"members\":[\"a\",\"missing\",\"a\",\"b\"]},{\"title\":\"Too small\",\"members\":[\"b\",\"c\"]}]}"}]]
		)
	end)
	assert.eq(fallback, false)
	assert.strContains(prompt, "heuristicComponents")
	assert.eq(#result.groups, 2)
	assert.eq(result.groups[1].source, "agent")
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
	assert.eq(result.groups[2].source, "heuristic")
	assert.eq(table.concat(result.groups[2].members, ","), "c,d")
end)

test.case("garbage agent reply keeps heuristic suggestions", function(assert)
	local doc = pair(json.object({ repo = "app", branch = "same" }), json.object({ repo = "app", branch = "same" }))
	local result, fallback = compute(doc, "codex", function(argv, stdin)
		assert.eq(argv[1], "codex")
		assert.strContains(stdin or "", "cards")
		return testing.result(true, "not JSON")
	end)
	assert.eq(fallback, true)
	assert.eq(result.groups[1].source, "heuristic")
end)

test.case("configured agent command receives bounded context on stdin", function(assert)
	local dir = testing.directory("suggest-command")
	local doc = pair(json.object({ repo = "app", branch = "same" }), json.object({ repo = "app", branch = "same" }))
	doc.raw = json.object({ settings = json.object({ agent = "claude", agentCommand = { "custom-agent", "--json" } }) })
	store.write(dir, doc)
	local output = ""
	cli.execute({ "suggest", "--dry-run", "--json" }, {
		dataDir = dir,
		write = function(value)
			output = value
		end,
		runner = function(argv, stdin)
			assert.eq(table.concat(argv, " "), "custom-agent --json")
			assert.strContains(stdin or "", "singletons")
			return testing.result(true, [[{"groups":[{"title":"Avatar work","members":["a","b"]}]}]])
		end,
	})
	local result = json.asObject(json.deserialize(output) :: json.Value)
	local groups = if result then json.asArray(result.groups) else nil
	local first = if groups then json.asObject(groups[1]) else nil
	assert.eq(first and first.source, "agent")
	assert.eq(store.load(dir).revision, 0)
end)

test.case("suggestions apply keeps links, marks layout pending, and prunes empty Unsorted", function(assert)
	local dir = testing.directory("suggest-apply")
	local doc = testing.doc({
		testing.group("unsorted", "Unsorted"),
		testing.task("a", "Avatar one", "todo", "unsorted", json.object({ repo = "app", branch = "same" })),
		testing.task("b", "Avatar two", "todo", "unsorted", json.object({ repo = "app", branch = "same" })),
	}, { { "a", "b" } })
	doc.links[1].origin = "mention"
	store.write(dir, doc)
	local output = {}
	local function run(args: { string })
		table.clear(output)
		cli.execute(args, {
			dataDir = dir,
			write = function(value)
				table.insert(output, value)
			end,
		})
		return table.concat(output)
	end
	run({ "suggest", "--dry-run" })
	assert.eq(store.load(dir).revision, 0)
	run({ "suggest" })
	assert.strContains(run({ "suggestions" }), "s1")
	run({ "suggestions", "apply", "s1" })
	local after = store.load(dir)
	assert.eq(after.revision, 2)
	assert.eq(graph.find(after, "unsorted"), nil)
	assert.eq(#after.links, 1)
	assert.eq(after.links[1].origin, "mention")
	assert.eq(after.nodes[1].parentId, after.nodes[3].id)
	assert.eq(after.nodes[2].parentId, after.nodes[3].id)
	assert.eq(after.nodes[3].data.layout, "pending")
	assert.eq(#suggest.stored(after).groups, 0)
end)

test.case("suggestions apply asks the app to tidy groups that lost cards", function(assert)
	local doc = testing.doc({
		testing.group("unsorted", "Unsorted"),
		testing.task("a", "Avatar one", "todo", "unsorted"),
		testing.task("b", "Avatar two", "todo", "unsorted"),
		testing.task("c", "Something else", "todo", "unsorted"),
	}, {})
	suggest.save(doc, {
		createdAt = "2026-10-04T00:00:00Z",
		groups = { { id = "s1", title = "Avatars", members = { "a", "b" }, reason = "", source = "agent" } },
	})
	suggest.change(doc, "apply", { "s1" }, false)
	local unsorted = graph.get(doc, "unsorted")
	assert.eq(unsorted.data.layout, "refit")
	assert.eq(graph.get(doc, "c").parentId, "unsorted")
end)

test.case("suggestions dismiss removes chosen suggestions without moving cards", function(assert)
	local doc = pair(json.object({ repo = "app", branch = "same" }), json.object({ repo = "app", branch = "same" }))
	suggest.save(doc, compute(doc))
	local changed = suggest.change(doc, "dismiss", { "s1" }, false)
	assert.eq(changed[1], "s1")
	assert.eq(#suggest.stored(doc).groups, 0)
	assert.eq(doc.nodes[1].parentId, nil)
end)
