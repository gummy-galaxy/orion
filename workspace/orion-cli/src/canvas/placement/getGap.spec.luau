local test = require("@std/test")

local geometry = require("@root/geometry")
local getGap = require("@root/canvas/placement/getGap")

test.case("getGap uses the inner gap inside a group and the wider one at the top level", function(assert)
	assert.eq(getGap("g"), geometry.GAP.inner)
	assert.eq(getGap(nil), geometry.GAP.top)
end)
