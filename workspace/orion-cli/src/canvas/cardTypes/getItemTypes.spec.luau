local json = require("@std/json")
local test = require("@std/test")

local getItemTypes = require("@root/canvas/cardTypes/getItemTypes")
local testing = require("@root/testing")

test.case("getItemTypes lists a card's own type, then its sources', then people's", function(assert)
	local refs = {
		json.object({ source = "jira", kind = "issue", key = "ORN-1" }),
		json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" }),
		json.object({ source = "github", kind = "issue", key = "vocksel/orion#3" }),
	}
	local item = testing.task("a", "A", "todo", nil, { itemKind = "pr", refs = refs, types = { "gate", "pr" } })
	local itemTypes = getItemTypes(item) :: any

	assert.eq(itemTypes.primary, "pr")
	assert.eq(table.concat(itemTypes.types, ","), "pr,step,placeholder,gate")
end)

test.case("getItemTypes gives a card with no kind the step type", function(assert)
	local item = testing.task("a", "A", "todo")
	item.data.itemKind = nil

	assert.eq(table.concat((getItemTypes(item) :: any).types, ","), "step")
end)

test.case("getItemTypes gives images their type, and groups none", function(assert)
	local image: any =
		{ id = "i", type = "image", position = { x = 0, y = 0 }, data = json.object({ asset = "a.png" }) }

	assert.eq((getItemTypes(image) :: any).primary, "image")
	assert.eq(getItemTypes(testing.group("g", "Group")), nil)
end)
