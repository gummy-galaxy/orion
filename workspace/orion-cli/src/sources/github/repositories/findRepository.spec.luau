local json = require("@std/json")
local test = require("@std/test")

local findRepository = require("@root/sources/github/repositories/findRepository")
local testing = require("@root/testing")

local function withDirectory(entries: { [string]: json.Object }): any
	local doc = testing.createDoc({})
	doc.repositories = json.object(entries :: any)
	return doc
end

test.case("a repository is found by its current name or an old one", function(assert)
	local doc = withDirectory({
		["1"] = json.object({ name = "gummy-galaxy/orion", aliases = { "vocksel/orion" } }),
	})

	local current = findRepository(doc, "Gummy-Galaxy/Orion")
	local old = findRepository(doc, "vocksel/orion")
	assert.eq(if current then current.key else nil, "1")
	assert.eq(if old then old.name else nil, "gummy-galaxy/orion")
	assert.eq(findRepository(doc, "flipbook-labs/flipbook"), nil)
end)

test.case("a current name wins over another repository's old name", function(assert)
	local doc = withDirectory({
		["1"] = json.object({ name = "gummy-galaxy/orion", aliases = { "vocksel/orion" } }),
		["2"] = json.object({ name = "vocksel/orion" }),
	})

	local found = findRepository(doc, "vocksel/orion")
	assert.eq(if found then found.key else nil, "2")
end)

test.case("Enterprise names are found only on their own host", function(assert)
	local doc = withDirectory({ ["ghe.example.com/1"] = json.object({ name = "team/app" }) })

	local found = findRepository(doc, "ghe.example.com/team/app")
	assert.eq(if found then found.key else nil, "ghe.example.com/1")
	assert.eq(findRepository(doc, "team/app"), nil)
end)

test.case("a canvas with no directory finds nothing", function(assert)
	assert.eq(findRepository(testing.createDoc({}), "vocksel/orion"), nil)
end)
