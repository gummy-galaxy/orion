local json = require("@std/json")
local test = require("@std/test")

local compute = require("@root/suggest/compute")
local linkItems = require("@root/graph/linkItems")
local testing = require("@root/testing")
local types = require("@root/types")

local function runUnexpected(_argv: { string }, _stdin: string?): types.CommandResult
	error("unexpected agent call")
end

local function getSuggestions(doc: types.Doc, agent: string?, runner: types.CommandRunner?, scope: string?)
	return compute(doc, scope or "unsorted", agent or "none", runner or runUnexpected, "2026-10-04T00:00:00Z")
end

local function getPair(extraA: json.Object?, extraB: json.Object?)
	return testing.createDoc({
		testing.task("a", "First work", "todo", nil, extraA),
		testing.task("b", "Second work", "todo", nil, extraB),
	})
end

test.case("heuristics join linked cards", function(assert)
	local doc = getPair()
	linkItems(doc, "a", "b", "related")
	local result = getSuggestions(doc)
	assert.eq(#result.groups, 1)
	assert.eq(result.groups[1].reason, "Linked work")
end)

test.case("heuristics join a shared Jira epic", function(assert)
	local doc = getPair(
		json.object({
			refs = {
				json.object({
					source = "jira",
					kind = "issue",
					key = "ITEM-1",
					details = json.object({ epicKey = "ABC-1", epicSummary = "Avatar loading" }),
				}),
			},
		}),
		json.object({
			refs = {
				json.object({
					source = "jira",
					kind = "issue",
					key = "ITEM-2",
					details = json.object({ epicKey = "ABC-1" }),
				}),
			},
		})
	)
	local result = getSuggestions(doc)
	assert.eq(result.groups[1].title, "Avatar loading")
	assert.eq(result.groups[1].reason, "Shared epic ABC-1")
end)

test.case("heuristics join the same repository branch", function(assert)
	local doc = getPair(
		json.object({
			repo = "vocksel/app",
			refs = { { source = "hop", kind = "branch", key = "vocksel/app@agent/avatar" } },
		}),
		json.object({
			repo = "vocksel/app",
			refs = { { source = "hop", kind = "branch", key = "vocksel/app@agent/avatar" } },
		})
	)
	table.insert(
		doc.nodes,
		testing.task(
			"c",
			"Other work",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "github.example.com/vocksel/app@agent/avatar" } },
			})
		)
	)
	local result = getSuggestions(doc)
	assert.eq(#result.groups, 1)
	assert.eq(table.concat(result.groups[1].members, ","), "a,b")
	assert.eq(result.groups[1].reason, "Shared branch agent/avatar")
end)

test.case("heuristics join issue references in titles and branches", function(assert)
	local doc = testing.createDoc({
		testing.task(
			"a",
			"Issue #123",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "github", kind = "issue", key = "vocksel/app#123" } },
			})
		),
		testing.task(
			"b",
			"Build view",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@fix-#123" } },
			})
		),
		testing.task("c", "ABC-9 migration", "todo"),
		testing.task(
			"d",
			"Migrate data",
			"todo",
			nil,
			json.object({
				repo = "vocksel/other",
				refs = { { source = "hop", kind = "branch", key = "vocksel/other@work/ABC-9" } },
			})
		),
	})
	local result = getSuggestions(doc)
	assert.eq(#result.groups, 2)
	assert.eq(result.groups[1].reason, "Shared Jira or issue reference")
	assert.eq(result.groups[2].reason, "Shared Jira or issue reference")
end)

test.case("title overlap joins only a matching repository without epic conflict", function(assert)
	local doc = testing.createDoc({
		testing.task("a", "Improve avatar loading", "todo", nil, json.object({ repo = "vocksel/app" })),
		testing.task("b", "Fix avatar loading", "todo", nil, json.object({ repo = "vocksel/app" })),
		testing.task("c", "Fix avatar loading", "todo", nil, json.object({ repo = "vocksel/other" })),
	})
	local result = getSuggestions(doc)
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
				repo = "vocksel/app",
				refs = {
					json.object({
						source = "jira",
						kind = "issue",
						key = "ITEM-3",
						details = json.object({ epicKey = "ABC-1" }),
					}),
				},
			})
		),
		testing.task(
			"b",
			"Fix avatar loading",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = {
					json.object({
						source = "jira",
						kind = "issue",
						key = "ITEM-4",
						details = json.object({ epicKey = "ABC-2" }),
					}),
				},
			})
		),
	})
	assert.eq(#getSuggestions(conflicting).groups, 0)
end)

test.case("default scope includes unsorted and top-level cards, ignoring notes", function(assert)
	local doc = testing.createDoc({
		testing.group("unsorted", "Unsorted"),
		testing.group("placed", "Placed"),
		testing.task("a", "Alpha loading", "todo", "unsorted", json.object({ repo = "vocksel/app" })),
		testing.task("b", "Alpha loading", "todo", nil, json.object({ repo = "vocksel/app" })),
		testing.task("c", "Alpha loading", "todo", "placed", json.object({ repo = "vocksel/app" })),
		testing.task("note", "Alpha loading", "todo", nil, json.object({ itemKind = "note", repo = "vocksel/app" })),
	})
	assert.eq(table.concat(getSuggestions(doc).groups[1].members, ","), "a,b")
	assert.eq(table.concat(getSuggestions(doc, nil, nil, "all").groups[1].members, ","), "a,b,c")
end)

test.case("agent reply drops unknown and duplicate ids while retaining ignored heuristics", function(assert)
	local doc = testing.createDoc({
		testing.task(
			"a",
			"Avatar one",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@avatar" } },
			})
		),
		testing.task(
			"b",
			"Avatar two",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@avatar" } },
			})
		),
		testing.task(
			"c",
			"Color one",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@color" } },
			})
		),
		testing.task(
			"d",
			"Color two",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@color" } },
			})
		),
	})
	local prompt = ""
	local result, didFallback = getSuggestions(doc, "claude", function(argv, stdin)
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
	local doc = getPair(
		json.object({ repo = "vocksel/app", refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } } }),
		json.object({ repo = "vocksel/app", refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } } })
	)
	local result, didFallback = getSuggestions(doc, "codex", function(argv, stdin)
		assert.eq(argv[1], "codex")
		assert.strContains(stdin or "", "cards")
		return testing.result(true, "not JSON")
	end)

	assert.eq(didFallback, true)
	assert.eq(result.groups[1].source, "heuristic")
end)
