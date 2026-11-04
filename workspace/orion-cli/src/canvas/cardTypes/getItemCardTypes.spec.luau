local json = require("@std/json")
local test = require("@std/test")

local getItemCardTypes = require("@root/canvas/cardTypes/getItemCardTypes")
local testing = require("@root/testing")

test.case("getItemCardTypes lists a card's own type, then its sources', then people's", function(assert)
	local refs = {
		json.object({ source = "jira", kind = "issue", key = "ORN-1" }),
		json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" }),
		json.object({ source = "github", kind = "issue", key = "vocksel/orion#3" }),
	}
	local item = testing.task("a", "A", "todo", nil, { refs = refs, types = { "gate", "pr" } })
	local itemTypes = getItemCardTypes(item) :: any

	assert.eq(itemTypes.primary, "pr")
	assert.eq(table.concat(itemTypes.types, ","), "pr,step,placeholder,gate")
end)

test.case("getItemCardTypes gives a card with no kind the step type", function(assert)
	local item = testing.task("a", "A", "todo")

	assert.eq(table.concat((getItemCardTypes(item) :: any).types, ","), "step")
end)

test.case("getItemCardTypes gives images their type, and groups none", function(assert)
	local image: any =
		{ id = "i", type = "image", position = { x = 0, y = 0 }, data = json.object({ asset = "a.png" }) }

	assert.eq((getItemCardTypes(image) :: any).primary, "image")
	assert.eq(getItemCardTypes(testing.group("g", "Group")), nil)
end)

test.case("getItemCardTypes lets a source's type supersede what a card would otherwise be", function(assert)
	local pull = json.object({ source = "github", kind = "pull", key = "vocksel/orion#12", type = "pr" })
	local ticket = json.object({ source = "jira", kind = "issue", key = "ORN-1", type = "step" })

	local expected = testing.task("a", "A", "todo", nil, { repo = "vocksel/orion" })
	assert.eq((getItemCardTypes(expected) :: any).primary, "placeholder")

	local opened = testing.task("b", "B", "todo", nil, { repo = "vocksel/orion", refs = { ticket, pull } })
	assert.eq(table.concat((getItemCardTypes(opened) :: any).types, ","), "pr,step")
end)

test.case("getItemCardTypes keeps the type a person chose when no source supersedes it", function(assert)
	local pull = json.object({ source = "github", kind = "pull", key = "vocksel/orion#12", type = "pr" })
	local gate = testing.task("a", "A", "todo", nil, { type = "gate", refs = { pull } })

	assert.eq(table.concat((getItemCardTypes(gate) :: any).types, ","), "gate,pr")
end)
