local json = require("@std/json")
local test = require("@std/test")

local detachCardType = require("@root/canvas/cardTypes/detachCardType")
local testing = require("@root/testing")

test.case("detachCardType takes off a type a person attached", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { types = { "gate", "note" } }) })
	local item = detachCardType(doc, "a", "gate")
	assert.eq(table.concat(item.data.types :: any, ","), "note")

	detachCardType(doc, "a", "note")
	assert.eq(item.data.types, nil)
end)

test.case("detachCardType says why it can't take off a type that came from elsewhere", function(assert)
	local pull = json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" })
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { refs = { pull } }) })

	assert.throwsWith(`can't detach step from "a": it's the card's own type`, function()
		detachCardType(doc, "a", "step")
	end)
	assert.throwsWith(`can't detach pr from "a": a source attached it`, function()
		detachCardType(doc, "a", "pr")
	end)
	assert.throwsWith(`can't detach gate from "a": it doesn't carry it`, function()
		detachCardType(doc, "a", "gate")
	end)
end)
