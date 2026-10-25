local json = require("@std/json")
local test = require("@std/test")

local fetchRenames = require("@root/github/fetchRenames")
local testing = require("@root/testing")

local function withRefs(id: string, refs: { json.Object }): any
	return testing.task(id, id, "active", nil, json.object({ refs = refs }))
end

local function ref(kind: string, key: string): json.Object
	return json.object({ source = "github", kind = kind, key = key })
end

test.case("one query asks for each repository the canvas names once", function(assert)
	local queries = {}
	local doc = testing.createDoc({
		withRefs("a", { ref("pull", "vocksel/orion#1"), ref("branch", "vocksel/orion@main") }),
		withRefs("b", { ref("issue", "Vocksel/Orion#2"), ref("issue", "flipbook-labs/flipbook#3") }),
		withRefs("c", { json.object({ source = "jira", kind = "issue", key = "ABC-1" }) }),
	})
	table.insert(doc.settings.checkSnoozes, { repo = "flipbook-labs/hop", name = "lint", at = "", passed = {} })

	fetchRenames(doc, function(argv)
		table.insert(queries, argv)
		return testing.result(true, '{"data": {}}')
	end)

	assert.eq(#queries, 1)
	local source = queries[1][#queries[1]]:lower()
	local _, count = source:gsub("repository%(", "")
	assert.eq(count, 3)
	assert.strContains(source, '"orion"')
	assert.strContains(source, '"flipbook"')
	assert.strContains(source, '"hop"')
	assert.strNotContains(source, "abc")
end)

test.case("a repository GitHub answers under another name has moved", function(assert)
	local doc = testing.createDoc({
		withRefs("a", { ref("pull", "vocksel/orion#1") }),
		withRefs("b", { ref("pull", "flipbook-labs/flipbook#2") }),
	})

	local renames = fetchRenames(doc, function(argv)
		local source = argv[#argv]
		local orion = if source:find('"orion"') then source:match('(r%d+): repository%(owner: "vocksel"') else nil
		local flipbook = if orion == "r1" then "r2" else "r1"
		return testing.result(
			true,
			`\{"data": \{"{orion}": \{"nameWithOwner": "gummy-galaxy/orion"}, "{flipbook}": \{"nameWithOwner": "flipbook-labs/flipbook"}}}`
		)
	end)

	assert.eq(renames["vocksel/orion"], "gummy-galaxy/orion")
	assert.eq(renames["flipbook-labs/flipbook"], nil)
end)

test.case("a change only in case isn't a move", function(assert)
	local doc = testing.createDoc({ withRefs("a", { ref("pull", "vocksel/orion#1") }) })

	local renames = fetchRenames(doc, function()
		return testing.result(true, '{"data": {"r1": {"nameWithOwner": "Vocksel/Orion"}}}')
	end)

	assert.eq(next(renames), nil)
end)

test.case("Enterprise repositories are asked on their own host", function(assert)
	local queries = {}
	local doc = testing.createDoc({ withRefs("a", { ref("pull", "ghe.example.com/team/app#1") }) })

	local renames = fetchRenames(doc, function(argv)
		table.insert(queries, argv)
		return testing.result(true, '{"data": {"r1": {"nameWithOwner": "platform/app"}}}')
	end)

	assert.eq(#queries, 1)
	assert.eq(table.find(queries[1], "--hostname") ~= nil, true)
	assert.eq(table.find(queries[1], "ghe.example.com") ~= nil, true)
	assert.eq(renames["ghe.example.com/team/app"], "platform/app")
end)

test.case("a failed query finds no moves", function(assert)
	local doc = testing.createDoc({ withRefs("a", { ref("pull", "vocksel/orion#1") }) })

	local renames = fetchRenames(doc, function()
		return testing.result(false, "", "network down")
	end)

	assert.eq(next(renames), nil)
end)

test.case("a canvas with no GitHub refs asks nothing", function(assert)
	local queries = 0

	fetchRenames(testing.createDoc({ testing.task("a", "A", "todo") }), function()
		queries += 1
		return testing.result(true, '{"data": {}}')
	end)

	assert.eq(queries, 0)
end)
