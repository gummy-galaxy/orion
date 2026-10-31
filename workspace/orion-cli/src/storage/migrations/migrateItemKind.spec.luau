local json = require("@std/json")
local test = require("@std/test")

local migrateItemKind = require("@root/storage/migrations/migrateItemKind")
local testing = require("@root/testing")

test.case("migrateItemKind keeps a kind a person chose as the card's type", function(assert)
	for _, kind in { "gate", "note", "component" } do
		local item = testing.task("a", "A", "todo", nil, { itemKind = kind })
		migrateItemKind(item)

		assert.eq(item.data.type, kind)
		assert.eq(item.data.itemKind, nil)
	end
end)

test.case("migrateItemKind leaves kinds that follow from refs and repository to them", function(assert)
	local pull = json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" })
	local issue = json.object({ source = "jira", kind = "issue", key = "ORN-1" })
	local item =
		testing.task("a", "A", "todo", nil, { itemKind = "pr", repo = "vocksel/orion", refs = { pull, issue } })
	migrateItemKind(item)

	assert.eq(item.data.type, nil)
	assert.eq(pull.type, "pr")
	assert.eq(issue.type, "step")
	assert.eq(testing.primaryType(item), "pr")

	local placeholder = testing.task("b", "B", "todo", nil, { itemKind = "placeholder", repo = "vocksel/orion" })
	migrateItemKind(placeholder)
	assert.eq(placeholder.data.type, nil)
	assert.eq(testing.primaryType(placeholder), "placeholder")
end)

test.case("migrateItemKind keeps a type the card already has", function(assert)
	local item = testing.task("a", "A", "todo", nil, { itemKind = "gate", type = "note" })
	migrateItemKind(item)

	assert.eq(item.data.type, "note")
end)
