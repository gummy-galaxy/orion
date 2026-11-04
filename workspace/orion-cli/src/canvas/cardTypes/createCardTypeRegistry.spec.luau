local test = require("@std/test")

local builtinCardTypes = require("@root/canvas/cardTypes/builtinCardTypes")
local cardTypes = require("@root/canvas/cardTypes/types")
local createCardTypeRegistry = require("@root/canvas/cardTypes/createCardTypeRegistry")

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

test.case("createCardTypeRegistry indexes every pack's types by name, in order", function(assert)
	local registry = createCardTypeRegistry({ builtinCardTypes, { thread("slack") } })

	assert.eq(registry.ordered[1].name, "step")
	assert.eq(registry.ordered[#registry.ordered].name, "slack.thread")
	assert.eq(registry.byName["slack.thread"].pack, "slack")
	assert.eq(registry.byName.gate.meaning.doneWhen, "inputs")
end)

test.case("createCardTypeRegistry refuses a name two packs declare", function(assert)
	assert.throwsWith("other declares slack.thread, which slack already declares", function()
		createCardTypeRegistry({ { thread("slack") }, { thread("other") } })
	end)
end)

test.case("createCardTypeRegistry checks each type as it registers", function(assert)
	local broken = thread("slack")
	broken.label = ""
	assert.throwsWith("slack.thread needs a label", function()
		createCardTypeRegistry({ { broken } })
	end)
end)
