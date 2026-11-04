local json = require("@std/json")
local test = require("@std/test")

local attachCardType = require("@root/canvas/cardTypes/attachCardType")
local testing = require("@root/testing")

test.case("attachCardType adds a type after the ones a card already carries", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	local item = attachCardType(doc, "a", "gate")
	attachCardType(doc, "a", "note")

	assert.eq(table.concat(item.data.types :: any, ","), "gate,note")
end)

test.case("attachCardType leaves a type the card already carries where it is", function(assert)
	local pull = json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" })
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { refs = { pull } }) })

	attachCardType(doc, "a", "step")
	attachCardType(doc, "a", "pr")

	assert.eq(doc.nodes[1].data.types, nil)
end)

test.case("attachCardType refuses unknown types and groups", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo"), testing.group("g", "Group") })

	assert.throwsWith("no type named figma.frame; orion card types shows them", function()
		attachCardType(doc, "a", "figma.frame")
	end)
	assert.throwsWith("groups don't take types; attach it to a card", function()
		attachCardType(doc, "g", "gate")
	end)
end)
