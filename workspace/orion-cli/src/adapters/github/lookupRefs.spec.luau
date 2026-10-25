local test = require("@std/test")

local lookupRefs = require("@root/adapters/github/lookupRefs")
local resolveRef = require("@root/adapters/resolveRef")
local testing = require("@root/testing")
local types = require("@root/types")

type ResolvedRef = types.ResolvedRef

local function resolveAll(urls: { string }): { ResolvedRef }
	local resolved = {}
	for _, url in urls do
		table.insert(resolved, resolveRef(url, {}))
	end
	return resolved
end

-- Aliases with no match come back as null, the way GraphQL answers a missing repository or number.
local function nullAliases(count: number): string
	local parts = {}
	for index = 1, count do
		table.insert(parts, `"p{index}": null`)
	end
	return '{"data": {' .. table.concat(parts, ", ") .. "}}"
end

test.case("one query looks up issues and pull requests from one repository", function(assert)
	local queries = {}
	local resolved = resolveAll({
		"https://github.com/vocksel/orion/issues/91",
		"https://github.com/vocksel/orion/pull/251",
	})
	local result = lookupRefs(
		resolved,
		{ now = "", since = "", doc = testing.createDoc({}), commands = {} },
		function(argv)
			table.insert(queries, argv)
			return testing.result(
				true,
				[[{"data": {
				"p1": {"issue": {"title": "Import a list of sources", "url": "https://github.com/vocksel/orion/issues/91"}},
				"p2": {"pullRequest": {"title": "Add --ref", "url": "https://github.com/vocksel/orion/pull/251"}}
			}}]]
			)
		end
	)

	assert.eq(#queries, 1)
	assert.strContains(queries[1][#queries[1]], "issue(number: 91)")
	assert.strContains(queries[1][#queries[1]], "pullRequest(number: 251)")

	local issue = result.records["issue:vocksel/orion#91"]
	assert.eq(issue.label, "Import a list of sources")
	assert.eq(issue.repo, "vocksel/orion")
	assert.eq(issue.ref.source, "github")
	assert.eq(issue.ref.url, "https://github.com/vocksel/orion/issues/91")
	assert.eq(issue.createWho, "you")
	assert.eq(issue.createStatus, "todo")

	local pull = result.records["pull:vocksel/orion#251"]
	assert.eq(pull.label, "Add --ref")
	assert.eq(pull.createWho, nil)
	assert.eq(next(result.failures), nil)
end)

test.case("refs that GitHub does not return are reported as not found", function(assert)
	local resolved = resolveAll({ "https://github.com/vocksel/orion/issues/999999" })
	local result = lookupRefs(resolved, { now = "", since = "", doc = testing.createDoc({}), commands = {} }, function()
		return testing.result(true, nullAliases(1))
	end)

	assert.eq(next(result.records), nil)
	assert.eq(result.failures["issue:vocksel/orion#999999"], "not found on github.com")
end)

test.case("a failed query fails every ref in its batch with the host", function(assert)
	local resolved = resolveAll({ "https://github.com/vocksel/orion/issues/1" })
	local result = lookupRefs(resolved, { now = "", since = "", doc = testing.createDoc({}), commands = {} }, function()
		return testing.result(false, "")
	end)

	assert.strContains(result.failures["issue:vocksel/orion#1"], "GitHub lookup on github.com failed")
end)

test.case("many refs are looked up in batches of 25 per host", function(assert)
	local urls = {}
	for number = 1, 30 do
		table.insert(urls, `https://github.com/vocksel/orion/issues/{number}`)
	end

	local calls = 0
	local result = lookupRefs(
		resolveAll(urls),
		{ now = "", since = "", doc = testing.createDoc({}), commands = {} },
		function()
			calls += 1
			return testing.result(true, nullAliases(25))
		end
	)

	assert.eq(calls, 2)
	assert.eq(result.failures["issue:vocksel/orion#30"], "not found on github.com")
end)

test.case("refs on a configured GitHub host query that host", function(assert)
	local hosts = {}
	local resolved = {
		resolveRef("https://github.example.com/Roblox/avatar/issues/3", {
			{ id = "gh-roblox", kind = "github", host = "github.example.com", owners = { "Roblox" } },
		}),
	}
	lookupRefs(resolved, { now = "", since = "", doc = testing.createDoc({}), commands = {} }, function(argv)
		table.insert(hosts, argv)
		return testing.result(true, nullAliases(1))
	end)

	assert.eq(hosts[1][3], "--hostname")
	assert.eq(hosts[1][4], "github.example.com")
end)

test.case("looked-up refs carry their repository's id", function(assert)
	local queries = {}
	local resolved = resolveAll({ "https://github.com/vocksel/orion/pull/251" })
	local result = lookupRefs(
		resolved,
		{ now = "", since = "", doc = testing.createDoc({}), commands = {} },
		function(argv)
			table.insert(queries, argv)
			return testing.result(
				true,
				[[{"data": {"p1": {"databaseId": 1, "pullRequest": {"title": "Add --ref", "url": "https://github.com/gummy-galaxy/orion/pull/251"}}}}]]
			)
		end
	)

	assert.strContains(queries[1][#queries[1]], "{ databaseId pullRequest(number: 251)")
	local pull = result.records["pull:vocksel/orion#251"]
	assert.eq(pull.ref.id, "1#251")
end)

return {}
