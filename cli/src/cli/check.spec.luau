local json = require("@std/json")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

test.case("check reports a clean canvas as clean in text and as an empty list in JSON", function(assert)
	local outer = testing.group("outer", "Outer")
	outer.width = 600
	outer.height = 300
	local first = testing.task("a", "A", "todo", "outer")
	first.position = { x = 32, y = 78 }
	local second = testing.task("b", "B", "todo", "outer")
	second.position = { x = 280, y = 78 }
	local dir = testing.directory("check-clean")
	store.write(dir, testing.createDoc({ outer, first, second }))
	assert.eq(testing.run(dir, { "canvas", "check" }), "No layout problems found.")
	local values = json.asArray(json.deserialize(testing.run(dir, { "canvas", "check", "--json" })) :: json.Value)
	assert.eq(values and #values, 0)
	assert.eq(testing.run(dir, { "canvas", "check", "--group", "outer" }), "No layout problems found.")
end)
