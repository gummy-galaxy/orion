local test = require("@std/test")

local lookupRefsAsync = require("@root/adapters/jira/lookupRefsAsync")
local resolveRef = require("@root/adapters/resolveRef")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

local JIRA: Source = {
	id = "jira",
	kind = "jira",
	browse = "https://jira.example.com/browse",
}

local COMMANDS = { jira = { "acli", "jira", "workitem", "search" } }

test.case("a Jira source runs once and matches each ref by key", function(assert)
	local calls = 0
	local doc = testing.createDoc({})
	doc.settings.sources = { JIRA }
	local resolved = { (resolveRef("jira:ABC-1", { JIRA })), (resolveRef("jira:ABC-2", { JIRA })) }
	local result = lookupRefsAsync(resolved, { now = "", since = "", doc = doc, commands = COMMANDS }, function(argv)
		calls += 1
		assert.eq(argv, { "acli", "jira", "workitem", "search" })
		return testing.result(true, '[{"key":"ABC-1","summary":"Ship","statusCategory":"new","type":"Task"}]')
	end)

	assert.eq(calls, 1)
	local record = result.records["issue:abc-1"]
	assert.eq(record.label, "Ship")
	assert.eq(record.ref.source, "jira")
	assert.eq(record.ref.url, "https://jira.example.com/browse/ABC-1")
	assert.eq(record.status, "todo")
	assert.eq(record.who, "you")
	assert.eq(result.failures["issue:abc-2"], "not in the jira source's results")
end)

test.case("a failing Jira command fails the refs of that source with its reason", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = { JIRA }
	local resolved = { (resolveRef("jira:ABC-1", { JIRA })) }
	local result = lookupRefsAsync(resolved, { now = "", since = "", doc = doc, commands = COMMANDS }, function()
		return { ok = false, exitCode = 1, stdout = "", stderr = "not logged in" }
	end)

	assert.eq(next(result.records), nil)
	assert.strContains(result.failures["issue:abc-1"], "could not read jira")
	assert.strContains(result.failures["issue:abc-1"], "not logged in")
end)

test.case("a Jira source with no command on this machine fails its refs with how to set one", function(assert)
	local doc = testing.createDoc({})
	doc.settings.sources = { JIRA }
	local resolved = { (resolveRef("jira:ABC-1", { JIRA })) }
	local result = lookupRefsAsync(resolved, { now = "", since = "", doc = doc, commands = {} }, function()
		error("ran a command")
	end)

	assert.strContains(result.failures["issue:abc-1"], "has no command on this machine")
	assert.strContains(result.failures["issue:abc-1"], "orion source add jira --id jira --command")
end)
