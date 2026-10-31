local json = require("@std/json")
local test = require("@std/test")

local detachType = require("@root/canvas/cardTypes/detachType")
local testing = require("@root/testing")

test.case("detachType takes off a type a person attached", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { types = { "gate", "note" } }) })
	local item = detachType(doc, "a", "gate")
	assert.eq(table.concat(item.data.types :: any, ","), "note")

	detachType(doc, "a", "note")
	assert.eq(item.data.types, nil)
end)

test.case("detachType says why it can't take off a type that came from elsewhere", function(assert)
	local pull = json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" })
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { refs = { pull } }) })

	assert.throwsWith(`can't detach step from "a": it's the card's own type`, function()
		detachType(doc, "a", "step")
	end)
	assert.throwsWith(`can't detach pr from "a": a source attached it`, function()
		detachType(doc, "a", "pr")
	end)
	assert.throwsWith(`can't detach gate from "a": it doesn't carry it`, function()
		detachType(doc, "a", "gate")
	end)
end)
