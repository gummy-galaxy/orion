local json = require("@std/json")
local test = require("@std/test")

local derive = require("@root/graph/derive")
local serializeDerived = require("@root/server/serializeDerived")
local testing = require("@root/testing")

test.case("serializeDerived writes every map as an object, even when empty", function(assert)
	local parsed = json.asObject(
		json.deserialize(json.serialize(serializeDerived(derive(testing.createDoc({}))))) :: json.Value
	) :: json.Object
	assert.eq(json.asObject(parsed.status) ~= nil, true)
	assert.eq(json.asObject(parsed.flow) ~= nil, true)
	assert.eq(json.asObject(parsed.leverage) ~= nil, true)
	assert.eq(json.asObject(parsed.upstream) ~= nil, true)
	assert.eq(json.asObject(parsed.rarity) ~= nil, true)
	assert.eq(json.asObject(parsed.groups) ~= nil, true)
	assert.eq(json.asObject(parsed.canvas) ~= nil, true)
	assert.eq(json.asObject(parsed.attention) ~= nil, true)
end)

test.case("serializeDerived keys values by item id and sends group counts", function(assert)
	local doc = testing.createDoc(
		{ testing.group("g", "Group"), testing.task("a", "A", "todo", "g"), testing.task("b", "B", "todo") },
		{ { "a", "b" } }
	)
	local parsed =
		json.asObject(json.deserialize(json.serialize(serializeDerived(derive(doc)))) :: json.Value) :: json.Object
	local status = json.asObject(parsed.status) :: json.Object
	local groups = json.asObject(parsed.groups) :: json.Object
	local stats = json.asObject(groups.g) :: json.Object
	assert.eq(status.a, "ready")
	assert.eq(status.b, "blocked")
	local rarity = json.asObject(parsed.rarity) :: json.Object
	assert.eq(rarity.a, "common")
	assert.eq(rarity.b, "common")
	assert.eq(stats.total, 1)
	assert.eq(stats.ready, 1)
	assert.eq(stats.outside, 1)
	local canvas = json.asObject(parsed.canvas) :: json.Object
	assert.eq(canvas.total, 2)
	assert.eq(canvas.ready, 1)
	assert.eq(canvas.blocked, 1)
end)

test.case("serializeDerived sends the work where it's your move", function(assert)
	local doc =
		testing.createDoc({ testing.task("a", "A", "todo", nil, { who = "you" }), testing.task("b", "B", "todo") })
	local parsed =
		json.asObject(json.deserialize(json.serialize(serializeDerived(derive(doc)))) :: json.Value) :: json.Object
	local attention = json.asObject(parsed.attention) :: json.Object
	assert.eq(attention.a, true)
	assert.eq(attention.b, nil)
end)
