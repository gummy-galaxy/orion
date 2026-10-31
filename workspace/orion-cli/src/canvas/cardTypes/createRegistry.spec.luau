local test = require("@std/test")

local builtinTypes = require("@root/canvas/cardTypes/builtinTypes")
local cardTypes = require("@root/canvas/cardTypes/types")
local createRegistry = require("@root/canvas/cardTypes/createRegistry")

type CardType = cardTypes.CardType

local function thread(pack: string): CardType
	return {
		name = "slack.thread",
		label = "Slack thread",
		pack = pack,
		fields = {},
		face = { layout = "note", shows = {} },
		states = {},
		meaning = { isWork = false, canBlock = false, canBeDone = true, doneWhen = "inputs" },
	}
end

test.case("createRegistry indexes every pack's types by name, in order", function(assert)
	local registry = createRegistry({ builtinTypes, { thread("slack") } })

	assert.eq(registry.ordered[1].name, "step")
	assert.eq(registry.ordered[#registry.ordered].name, "slack.thread")
	assert.eq(registry.byName["slack.thread"].pack, "slack")
	assert.eq(registry.byName.gate.meaning.doneWhen, "inputs")
end)

test.case("createRegistry refuses a name two packs declare", function(assert)
	assert.throwsWith("other declares slack.thread, which slack already declares", function()
		createRegistry({ { thread("slack") }, { thread("other") } })
	end)
end)

test.case("createRegistry checks each type as it registers", function(assert)
	local broken = thread("slack")
	broken.label = ""
	assert.throwsWith("slack.thread needs a label", function()
		createRegistry({ { broken } })
	end)
end)
