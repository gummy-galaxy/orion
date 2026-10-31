local json = require("@std/json")
local test = require("@std/test")

local cardTypes = require("@root/cardTypes/types")
local setFieldValue = require("@root/graph/setFieldValue")
local testing = require("@root/testing")

type CardType = cardTypes.CardType

local FRAME: CardType = {
	name = "figma.frame",
	label = "Figma frame",
	pack = "figma",
	fields = {
		{ name = "file", label = "File", kind = "url" },
		{ name = "screens", label = "Screens", kind = "number" },
		{ name = "shared", label = "Shared", kind = "boolean" },
		{ name = "due", label = "Due", kind = "date" },
		{
			name = "stage",
			label = "Stage",
			kind = "choice",
			choices = { { value = "draft", label = "Draft" }, { value = "final", label = "Final" } },
			default = "draft",
		},
	},
	face = { layout = "card", shows = { "stage" } },
	states = { { name = "approved", label = "Approved", means = "done" } },
	meaning = { isWork = true, canBlock = true, canBeDone = true, doneWhen = "state" },
}

test.case("setFieldValue stores each kind of field as its type declares it", function(assert)
	testing.withCardTypes({ FRAME }, function()
		local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { types = { "figma.frame" } }) })

		setFieldValue(doc, "a", "file", "https://figma.com/file/abc")
		setFieldValue(doc, "a", "screens", "4")
		setFieldValue(doc, "a", "shared", "true")
		setFieldValue(doc, "a", "due", "2026-11-02")
		local item = setFieldValue(doc, "a", "stage", "final")
		local fields = json.asObject(item.data.fields) :: json.Object

		assert.eq(fields.file, "https://figma.com/file/abc")
		assert.eq(fields.screens, 4)
		assert.eq(fields.shared, true)
		assert.eq(fields.due, "2026-11-02")
		assert.eq(fields.stage, "final")
	end)
end)

test.case("setFieldValue clears a field with empty text, and drops the table once empty", function(assert)
	testing.withCardTypes({ FRAME }, function()
		local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { types = { "figma.frame" } }) })

		setFieldValue(doc, "a", "stage", "final")
		local item = setFieldValue(doc, "a", "stage", "")

		assert.eq(item.data.fields, nil)
	end)
end)

test.case("setFieldValue refuses values outside a field's kind", function(assert)
	testing.withCardTypes({ FRAME }, function()
		local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { types = { "figma.frame" } }) })

		for _, case in
			{
				{ "screens", "four", "screens must be a number" },
				{ "shared", "yes", "shared must be true or false" },
				{ "stage", "shipped", "stage must be one of draft, final" },
				{ "due", "next week", "due must be a date such as 2026-10-26" },
				{ "file", "figma.com/file/abc", "file must be an http or https URL" },
			}
		do
			assert.throwsWith(case[3], function()
				setFieldValue(doc, "a", case[1], case[2])
			end)
		end
	end)
end)

test.case("setFieldValue refuses fields no type on the card declares, and core fields", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })

	assert.throwsWith(`none of "a"'s types has a field named stage; orion type show lists a type's fields`, function()
		setFieldValue(doc, "a", "stage", "final")
	end)
	assert.throwsWith("set who with --who", function()
		setFieldValue(doc, "a", "who", "you")
	end)
end)
