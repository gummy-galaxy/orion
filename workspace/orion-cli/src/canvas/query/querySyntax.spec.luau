local test = require("@std/test")

local parseExpression = require("@root/canvas/query/parseExpression")
local parseSort = require("@root/canvas/query/parseSort")
local querySyntax = require("@root/canvas/query/querySyntax")

test.case("every documented field and example parses", function(assert)
	for _, field in querySyntax.fields do
		assert.eq(parseExpression(field.example).field, field.name)
	end

	for _, example in querySyntax.examples do
		parseExpression(example)
	end

	for _, example in querySyntax.sortExamples do
		parseSort(example)
	end
end)

test.case("~ works on text fields only", function(assert)
	for _, field in querySyntax.fields do
		local expression = `{field.name} ~ "x"`

		if field.isText then
			assert.eq(parseExpression(expression).operator, "~")
		else
			assert.throwsWith(`'~' is only supported for group, priority, label, note, and ref`, function()
				parseExpression(expression)
			end)
		end
	end
end)

test.case("a field with a fixed set of values refuses others", function(assert)
	assert.throwsWith("query at column 14: draft must be 'true' or 'false'", function()
		parseExpression([[draft = "yes"]])
	end)
	assert.throwsWith("query at column 16: snoozed must be 'true' or 'false'", function()
		parseExpression([[snoozed = "yes"]])
	end)
end)
