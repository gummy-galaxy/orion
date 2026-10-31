local test = require("@std/test")

local trimText = require("@root/common/text/trimText")

test.case("text is cut by characters, never inside one", function(assert)
	assert.eq(trimText("short", 10), "short")
	assert.eq(trimText("abcdef", 3), "abc")
	assert.eq(trimText("héllo", 2), "hé")
	assert.eq(trimText("", 3), "")
end)
