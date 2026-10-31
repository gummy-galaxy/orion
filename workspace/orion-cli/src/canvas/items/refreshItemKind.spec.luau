local test = require("@std/test")

local refreshItemKind = require("@root/canvas/items/refreshItemKind")
local testing = require("@root/testing")

test.case("refreshItemKind follows the repository and pull request, and keeps gates", function(assert)
	local item = testing.task("a", "A", "todo", nil, { repo = "vocksel/orion" })
	refreshItemKind(item)
	assert.eq(item.data.itemKind, "placeholder")

	item.data.refs = { { source = "github", kind = "pull", key = "vocksel/orion#1" } } :: any
	refreshItemKind(item)
	assert.eq(item.data.itemKind, "pr")

	local gate = testing.task("g", "Ship", "todo", nil, { itemKind = "gate", repo = "vocksel/orion" })
	refreshItemKind(gate)
	assert.eq(gate.data.itemKind, "gate")
end)

test.case("refreshItemKind leaves notes and components alone", function(assert)
	local note = testing.task("n", "Remember", "todo", nil, { itemKind = "note", repo = "vocksel/orion" })
	local component = testing.task("api", "API", "todo", nil, { itemKind = "component", repo = "vocksel/orion" })
	refreshItemKind(note)
	refreshItemKind(component)
	assert.eq(note.data.itemKind, "note")
	assert.eq(component.data.itemKind, "component")
end)
