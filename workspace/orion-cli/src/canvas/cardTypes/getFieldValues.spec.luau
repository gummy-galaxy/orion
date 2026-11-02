local json = require("@std/json")
local test = require("@std/test")

local getFieldValues = require("@root/canvas/cardTypes/getFieldValues")
local testing = require("@root/testing")

test.case("getFieldValues lists each declared field once, with the card's value or its default", function(assert)
	testing.withCardTypes({
		{
			name = "review.round",
			label = "Review round",
			pack = "review",
			fields = {
				{ name = "who", label = "Reviewer", kind = "text" },
				{ name = "round", label = "Round", kind = "number", default = 1 },
			},
			face = { layout = "card", shows = { "round" } },
			states = {},
			meaning = { isWork = false, canBlock = false, canBeDone = true, doneWhen = "inputs" },
		},
	}, function()
		local item = testing.task("a", "A", "todo", nil, {
			who = "you",
			types = { "review.round" },
			fields = json.object({ round = 3 }),
		})
		local names: { string } = {}

		for _, entry in getFieldValues(item) do
			table.insert(names, `{entry.type}.{entry.field.name}={tostring(entry.value)}`)
		end

		-- The step's who comes first, so the attached type's who adds nothing.
		assert.eq(table.concat(names, ","), "step.who=you,review.round.round=3")

		item.data.fields = nil
		assert.eq(getFieldValues(item)[2].value, 1)
	end)
end)
