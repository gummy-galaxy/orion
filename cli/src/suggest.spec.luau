local json = require("@std/json")
local test = require("@std/test")

local graph = require("@root/graph")
local suggest = require("@root/suggest")
local testing = require("@root/testing")
local types = require("@root/types")

local function runUnexpected(_argv: { string }, _stdin: string?): types.CommandResult
	error("unexpected agent call")
end

local function compute(doc: types.Doc, agent: string?, runner: types.CommandRunner?, scope: string?)
	return suggest.compute(doc, scope or "unsorted", agent or "none", runner or runUnexpected, "2026-10-04T00:00:00Z")
end

local function getPair(extraA: json.Object?, extraB: json.Object?)
	return testing.createDoc({
		testing.task("a", "First work", "todo", nil, extraA),
		testing.task("b", "Second work", "todo", nil, extraB),
	})
end

test.case("heuristics join linked cards", function(assert)
	local doc = getPair()
	graph.link(doc, "a", "b", "related")
	local result = compute(doc)
	assert.eq(#result.groups, 1)
	assert.eq(result.groups[1].reason, "Linked work")
end)

test.case("heuristics join a shared Jira epic", function(assert)
	local doc = getPair(
		json.object({
			external = json.object({
				source = "jira",
				key = "ITEM-1",
				details = json.object({ epicKey = "ABC-1", epicSummary = "Avatar loading" }),
			}),
		}),
		json.object({
			external = json.object({ source = "jira", key = "ITEM-2", details = json.object({ epicKey = "ABC-1" }) }),
		})
	)
	local result = compute(doc)
	assert.eq(result.groups[1].title, "Avatar loading")
	assert.eq(result.groups[1].reason, "Shared epic ABC-1")
end)

test.case("heuristics join the same repository branch", function(assert)
	local doc = getPair(
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
	local doc = testing.createDoc({
		testing.task("a", "Issue #123", "todo", nil, json.object({ repo = "app", issue = 123 })),
		testing.task("b", "Build view", "todo", nil, json.object({ repo = "app", branch = "fix-#123" })),
		testing.task("c", "ABC-9 migration", "todo"),
		testing.task("d", "Migrate data", "todo", nil, json.object({ branch = "work/ABC-9" })),
	})
	local result = compute(doc)
	assert.eq(#result.groups, 2)
	assert.eq(result.groups[1].reason, "Shared Jira or issue reference")
	assert.eq(result.groups[2].reason, "Shared Jira or issue reference")
end)

test.case("title overlap joins only a matching repository without epic conflict", function(assert)
	local doc = testing.createDoc({
		testing.task("a", "Improve avatar loading", "todo", nil, json.object({ repo = "app" })),
		testing.task("b", "Fix avatar loading", "todo", nil, json.object({ repo = "app" })),
		testing.task("c", "Fix avatar loading", "todo", nil, json.object({ repo = "other" })),
	})
	local result = compute(doc)
	assert.eq(#result.groups, 1)
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
	assert.eq(result.groups[1].reason, "Strong title overlap")

	local conflicting = testing.createDoc({
		testing.task(
			"a",
			"Improve avatar loading",
			"todo",
			nil,
			json.object({
				repo = "app",
				external = json.object({
					source = "jira",
					key = "ITEM-3",
					details = json.object({ epicKey = "ABC-1" }),
				}),
			})
		),
		testing.task(
			"b",
			"Fix avatar loading",
			"todo",
			nil,
			json.object({
				repo = "app",
				external = json.object({
					source = "jira",
					key = "ITEM-4",
					details = json.object({ epicKey = "ABC-2" }),
				}),
			})
		),
	})
	assert.eq(#compute(conflicting).groups, 0)
end)

test.case("default scope includes unsorted and top-level cards, ignoring notes", function(assert)
	local doc = testing.createDoc({
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
	local doc = testing.createDoc({
		testing.task("a", "Avatar one", "todo", nil, json.object({ repo = "app", branch = "avatar" })),
		testing.task("b", "Avatar two", "todo", nil, json.object({ repo = "app", branch = "avatar" })),
		testing.task("c", "Color one", "todo", nil, json.object({ repo = "app", branch = "color" })),
		testing.task("d", "Color two", "todo", nil, json.object({ repo = "app", branch = "color" })),
	})
	local prompt = ""
	local result, didFallback = compute(doc, "claude", function(argv, stdin)
		assert.eq(argv[1], "claude")
		prompt = stdin
		return testing.result(
			true,
			[[{"result":"{\"groups\":[{\"title\":\"Avatar work\",\"members\":[\"a\",\"missing\",\"a\",\"b\"]},{\"title\":\"Too small\",\"members\":[\"b\",\"c\"]}]}"}]]
		)
	end)
	assert.eq(didFallback, false)
	assert.strContains(prompt, "heuristicComponents")
	assert.eq(#result.groups, 2)
	assert.eq(result.groups[1].source, "agent")
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
	assert.eq(result.groups[2].source, "heuristic")
	assert.eq(table.concat(result.groups[2].members, ","), "c,d")
end)

test.case("garbage agent reply keeps heuristic suggestions", function(assert)
	local doc = getPair(json.object({ repo = "app", branch = "same" }), json.object({ repo = "app", branch = "same" }))
	local result, didFallback = compute(doc, "codex", function(argv, stdin)
		assert.eq(argv[1], "codex")
		assert.strContains(stdin or "", "cards")
		return testing.result(true, "not JSON")
	end)
	assert.eq(didFallback, true)
	assert.eq(result.groups[1].source, "heuristic")
end)

test.case("suggestions apply asks the app to tidy groups that lost cards", function(assert)
	local doc = testing.createDoc({
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
	local doc = getPair(json.object({ repo = "app", branch = "same" }), json.object({ repo = "app", branch = "same" }))
	suggest.save(doc, compute(doc))
	local changed = suggest.change(doc, "dismiss", { "s1" }, false)
	assert.eq(changed[1], "s1")
	assert.eq(#suggest.getStored(doc).groups, 0)
	assert.eq(doc.nodes[1].parentId, nil)
end)
