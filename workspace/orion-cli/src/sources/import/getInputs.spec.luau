local test = require("@std/test")

local getInputs = require("@root/sources/import/getInputs")

test.case("arguments come first, then stdin lines, with blanks and spaces dropped", function(assert)
	local inputs = getInputs(
		{ "https://github.com/vocksel/orion/issues/1", "  jira:ABC-2  " },
		"https://github.com/vocksel/orion/issues/3\r\n\n   \njira:ABC-4"
	)

	assert.eq(inputs, {
		"https://github.com/vocksel/orion/issues/1",
		"jira:ABC-2",
		"https://github.com/vocksel/orion/issues/3",
		"jira:ABC-4",
	})
end)

test.case("no arguments and no stdin gives no inputs", function(assert)
	assert.eq(getInputs({}, nil), {})
	assert.eq(getInputs({}, ""), {})
end)
