local test = require("@std/test")

local formatList = require("@root/render/formatList")

test.case("joins one, two, and more words into prose", function(assert)
	assert.eq(formatList({ "label" }), "label")
	assert.eq(formatList({ "true", "false" }, "or", "'"), "'true' or 'false'")
	assert.eq(formatList({ "label", "note", "ref" }), "label, note, and ref")
end)
