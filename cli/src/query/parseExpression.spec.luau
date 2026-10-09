local test = require("@std/test")

local parseExpression = require("@root/query/parseExpression")

test.case("parses comparisons and boolean precedence", function(assert)
	local expression = parseExpression([[repo = "orion" or not (label ~ 'draft' and pr != "86")]])
	assert.eq(expression.kind, "or")
	assert.eq(expression.left and expression.left.field, "repo")
	assert.eq(expression.right and expression.right.kind, "not")
	assert.eq(expression.right and expression.right.left and expression.right.left.kind, "and")
end)

test.case("parses escaped quote and backslash as literal text", function(assert)
	local expression = parseExpression([[label = "a\"b\\c"]])
	assert.eq(expression.value, [[a"b\c]])
end)

test.case("reports unknown fields and syntax at a column", function(assert)
	for _, expression in
		{
			[[owner = "x"]],
			[[repo = orion]],
			[[label ~ "x" and]],
			[[(repo = "x"]],
			[[status = "todo" garbage]],
			[[repo ~ "x"]],
			[[draft = "maybe"]],
			[[label = "unfinished]],
		}
	do
		assert.throws(function()
			parseExpression(expression)
		end)
	end
	assert.throwsWith("query at column 6: unknown field 'owner'", function()
		parseExpression([[owner = "x"]])
	end)
end)
