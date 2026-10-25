local json = require("@std/json")
local test = require("@std/test")

local change = require("@root/suggest/change")
local compute = require("@root/suggest/compute")
local getItem = require("@root/graph/getItem")
local getStored = require("@root/suggest/getStored")
local save = require("@root/suggest/save")
local testing = require("@root/testing")
local types = require("@root/types")

local function runUnexpected(_argv: { string }, _stdin: string?): types.CommandResult
	error("unexpected command call")
end

local function getSuggestions(doc: types.Doc)
	return compute(doc, "unsorted", nil, runUnexpected, "2026-10-04T00:00:00Z")
end

local function getPair(extraA: json.Object?, extraB: json.Object?)
	return testing.createDoc({
		testing.task("a", "First work", "todo", nil, extraA),
		testing.task("b", "Second work", "todo", nil, extraB),
	})
end

test.case("suggestions apply asks the app to tidy groups that lost cards", function(assert)
	local doc = testing.createDoc({
		testing.group("unsorted", "Unsorted"),
		testing.task("a", "Avatar one", "todo", "unsorted"),
		testing.task("b", "Avatar two", "todo", "unsorted"),
		testing.task("c", "Something else", "todo", "unsorted"),
	}, {})
	save(doc, {
		createdAt = "2026-10-04T00:00:00Z",
		groups = { { id = "s1", title = "Avatars", members = { "a", "b" }, reason = "", source = "agent" } },
	})
	change(doc, "apply", { "s1" }, false)
	local unsorted = getItem(doc, "unsorted")
	assert.eq(unsorted.data.layout, "refit")
	assert.eq(getItem(doc, "c").parentId, "unsorted")
end)

test.case("suggestions dismiss removes chosen suggestions without moving cards", function(assert)
	local doc = getPair(
		json.object({ repo = "vocksel/app", refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } } }),
		json.object({ repo = "vocksel/app", refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } } })
	)
	save(doc, getSuggestions(doc))
	local changed = change(doc, "dismiss", { "s1" }, false)
	assert.eq(changed[1], "s1")
	assert.eq(#getStored(doc).groups, 0)
	assert.eq(doc.nodes[1].parentId, nil)
end)
