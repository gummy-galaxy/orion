local test = require("@std/test")

local refreshItemKind = require("@root/canvas/items/refreshItemKind")
local testing = require("@root/testing")

test.case("refreshItemKind follows the repository and pull request, and keeps gates", function(assert)
	local item = testing.task("a", "A", "todo", nil, { repo = "vocksel/orion" })
	refreshItemKind(item)
	assert.eq(item.data.type, "placeholder")

	item.data.refs = { { source = "github", kind = "pull", key = "vocksel/orion#1" } } :: any
	refreshItemKind(item)
	assert.eq(item.data.type, "pr")

	local gate = testing.task("g", "Ship", "todo", nil, { type = "gate", repo = "vocksel/orion" })
	refreshItemKind(gate)
	assert.eq(gate.data.type, "gate")
end)

test.case("refreshItemKind leaves notes and components alone", function(assert)
	local note = testing.task("n", "Remember", "todo", nil, { type = "note", repo = "vocksel/orion" })
	local component = testing.task("api", "API", "todo", nil, { type = "component", repo = "vocksel/orion" })
	refreshItemKind(note)
	refreshItemKind(component)
	assert.eq(note.data.type, "note")
	assert.eq(component.data.type, "component")
end)
