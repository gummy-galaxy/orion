local test = require("@std/test")

local checkHeader = require("@root/canvas/appearance/checkHeader")

test.case("a header of Markdown and layout HTML is accepted", function(assert)
	assert.eq(checkHeader('# Sprint 14\n\n<div class="header-row">Ship it</div>'), nil)
end)

test.case("a header longer than 2000 characters is refused", function(assert)
	assert.throws(function()
		checkHeader(string.rep("a", 2001))
	end)
	assert.eq(checkHeader(string.rep("a", 2000)), nil)
end)
