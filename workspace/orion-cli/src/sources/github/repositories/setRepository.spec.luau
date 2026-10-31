local json = require("@std/json")
local test = require("@std/test")

local setRepository = require("@root/sources/github/repositories/setRepository")
local testing = require("@root/testing")

local function entry(doc: any, key: string): json.Object
	return json.asObject(doc.repositories[key]) :: json.Object
end

test.case("a repository's former name and the name GitHub answered for it stay as aliases", function(assert)
	local doc = testing.createDoc({})
	setRepository(doc, nil, "1", "vocksel/orion", "first")
	setRepository(doc, nil, "1", "gummy-galaxy/orion", "second")
	setRepository(doc, nil, "1", "gummy-galaxy/orion", "third", "old-owner/orion")

	local recorded = entry(doc, "1")
	assert.eq(recorded.name, "gummy-galaxy/orion")
	assert.eq(recorded.checkedAt, "third")
	local aliases = json.asArray(recorded.aliases) or {}
	assert.eq(#aliases, 2)
	assert.eq(aliases[1], "vocksel/orion")
	assert.eq(aliases[2], "old-owner/orion")
end)

test.case("a name another repository takes stops being an old repository's alias", function(assert)
	local doc = testing.createDoc({})
	setRepository(doc, nil, "1", "gummy-galaxy/orion", "first", "vocksel/orion")
	setRepository(doc, nil, "2", "vocksel/orion", "second")

	assert.eq(entry(doc, "1").aliases, nil)
	assert.eq(entry(doc, "2").name, "vocksel/orion")
end)

test.case("an Enterprise repository is kept under its host", function(assert)
	local doc = testing.createDoc({})
	setRepository(doc, "GHE.example.com", "1", "team/app", "now")

	assert.eq(entry(doc, "ghe.example.com/1").name, "team/app")
end)
