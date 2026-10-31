local test = require("@std/test")

local cardTypes = require("@root/canvas/cardTypes/types")
local checkCardType = require("@root/canvas/cardTypes/checkCardType")

type CardType = cardTypes.CardType

local function frame(): CardType
	return {
		name = "figma.frame",
		label = "Figma frame",
		pack = "figma",
		fields = {
			{ name = "file", label = "File", kind = "url" },
			{
				name = "stage",
				label = "Stage",
				kind = "choice",
				choices = { { value = "draft", label = "Draft" }, { value = "final", label = "Final" } },
				default = "draft",
			},
		},
		face = { layout = "card", shows = { "stage" } },
		states = {
			{ name = "drafting", label = "Drafting", means = "active" },
			{ name = "approved", label = "Approved", means = "done" },
		},
		meaning = { isWork = true, canBlock = true, canBeDone = true, doneWhen = "state" },
	}
end

test.case("checkCardType accepts a type from another pack", function(assert)
	checkCardType(frame())
	assert.eq(true, true)
end)

test.case("checkCardType refuses names that don't read the same everywhere", function(assert)
	for _, name in { "Figma", "9frame", "figma frame", "" } do
		local cardType = frame()
		cardType.name = name
		assert.throws(function()
			checkCardType(cardType)
		end)
	end
end)

test.case("checkCardType refuses a face that shows a field the type doesn't declare", function(assert)
	local cardType = frame()
	cardType.face.shows = { "owner" }
	assert.throwsWith("figma.frame shows owner, which it doesn't declare", function()
		checkCardType(cardType)
	end)
end)

test.case("checkCardType refuses fields declared twice or with a default outside their choices", function(assert)
	local twice = frame()
	table.insert(twice.fields, { name = "file", label = "Again", kind = "text" :: any })
	assert.throwsWith("figma.frame declares file twice", function()
		checkCardType(twice)
	end)

	local outside = frame()
	outside.fields[2].default = "shipped"
	assert.throwsWith("figma.frame's stage default isn't one of its choices", function()
		checkCardType(outside)
	end)

	local unlisted = frame()
	unlisted.fields[1].choices = { { value = "a", label = "A" } }
	assert.throwsWith("figma.frame's file takes choices only when its kind is choice", function()
		checkCardType(unlisted)
	end)
end)

test.case("checkCardType refuses meanings that contradict the states", function(assert)
	local stateless = frame()
	stateless.states = {}
	assert.throwsWith("figma.frame is done by its state, so it needs states", function()
		checkCardType(stateless)
	end)

	local undoable = frame()
	undoable.meaning = { isWork = false, canBlock = false, canBeDone = false, doneWhen = "state" }
	assert.throwsWith("figma.frame can't be done, so it takes no states", function()
		checkCardType(undoable)
	end)

	local idleWork = frame()
	idleWork.states = {}
	idleWork.meaning = { isWork = true, canBlock = true, canBeDone = false, doneWhen = "state" }
	assert.throwsWith("figma.frame is work, so it must be able to be done", function()
		checkCardType(idleWork)
	end)
end)

test.case("checkCardType refuses states with an unknown meaning", function(assert)
	local cardType = frame()
	cardType.states[1].means = "shipped" :: any
	assert.throwsWith("figma.frame's drafting state has an unknown meaning shipped", function()
		checkCardType(cardType)
	end)
end)
