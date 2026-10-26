local json = require("@std/json")
local test = require("@std/test")

local fetchRepositoriesAsync = require("@root/github/fetchRepositoriesAsync")
local testing = require("@root/testing")

local function card(id: string, refs: { json.Object }): any
	return testing.task(id, id, "active", nil, json.object({ refs = refs }))
end

local function ref(kind: string, key: string, id: string?): json.Object
	return json.object({ source = "github", kind = kind, key = key, id = id })
end

test.case("one query asks for each repository whose refs have no id yet", function(assert)
	local queries = {}
	local doc = testing.createDoc({
		card("a", { ref("pull", "vocksel/orion#1"), ref("branch", "Vocksel/Orion@main") }),
		card("b", { ref("pull", "flipbook-labs/flipbook#2", "R_9#2") }),
		card("c", { json.object({ source = "jira", kind = "issue", key = "ABC-1" }) }),
	})

	local found = fetchRepositoriesAsync(doc, function(argv)
		table.insert(queries, argv)
		return testing.result(true, '{"data": {"r1": {"databaseId": 1, "nameWithOwner": "gummy-galaxy/orion"}}}')
	end)

	assert.eq(#queries, 1)
	local source = queries[1][#queries[1]]:lower()
	local _, count = source:gsub("repository%(", "")
	assert.eq(count, 1)
	assert.strContains(source, '"orion"')
	assert.strNotContains(source, "flipbook")
	assert.eq(#found, 1)
	assert.eq(found[1].location, "vocksel/orion")
	assert.eq(found[1].id, "1")
	assert.eq(found[1].name, "gummy-galaxy/orion")
	assert.eq(found[1].host, "github.com")
end)

test.case("Enterprise repositories are asked on their own host", function(assert)
	local queries = {}
	local doc = testing.createDoc({ card("a", { ref("pull", "ghe.example.com/team/app#1") }) })

	local found = fetchRepositoriesAsync(doc, function(argv)
		table.insert(queries, argv)
		return testing.result(true, '{"data": {"r1": {"databaseId": 2, "nameWithOwner": "team/app"}}}')
	end)

	assert.eq(table.find(queries[1], "ghe.example.com") ~= nil, true)
	assert.eq(found[1].location, "ghe.example.com/team/app")
	assert.eq(found[1].host, "ghe.example.com")
end)

test.case("a repository GitHub doesn't find, or a failed query, finds nothing", function(assert)
	local doc = testing.createDoc({ card("a", { ref("pull", "vocksel/orion#1") }) })

	assert.eq(#fetchRepositoriesAsync(doc, function()
		return testing.result(true, '{"data": {"r1": null}}')
	end), 0)
	assert.eq(#fetchRepositoriesAsync(doc, function()
		return testing.result(false, "", "network down")
	end), 0)
end)

test.case("a canvas whose refs all have ids asks nothing", function(assert)
	local queries = 0
	local doc = testing.createDoc({ card("a", { ref("pull", "vocksel/orion#1", "R_1#1") }) })

	fetchRepositoriesAsync(doc, function()
		queries += 1
		return testing.result(true, '{"data": {}}')
	end)

	assert.eq(queries, 0)
end)
