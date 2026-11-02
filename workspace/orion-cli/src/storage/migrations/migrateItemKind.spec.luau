local json = require("@std/json")
local test = require("@std/test")

local migrateItemKind = require("@root/storage/migrations/migrateItemKind")
local types = require("@root/types")

type Item = types.Item

local function task(data: json.Object): Item
	return { id = "card", type = "task", position = { x = 0, y = 0 }, data = data }
end

test.case("migrateItemKind moves a card's itemKind to type", function(assert)
	local item = task(json.object({ kind = "task", label = "Ship", itemKind = "gate", status = "todo" }))
	migrateItemKind(item)

	assert.eq(item.data.type, "gate")
	assert.eq(item.data.itemKind, nil)
end)

test.case("migrateItemKind keeps a type the card already has", function(assert)
	local item = task(json.object({ kind = "task", itemKind = "step", type = "note" }))
	migrateItemKind(item)

	assert.eq(item.data.type, "note")
	assert.eq(item.data.itemKind, nil)
end)

test.case("migrateItemKind leaves a card without itemKind alone", function(assert)
	local item = task(json.object({ kind = "task", label = "Plain", type = "pr" }))
	migrateItemKind(item)

	assert.eq(item.data.type, "pr")
	assert.eq(item.data.itemKind, nil)
end)
