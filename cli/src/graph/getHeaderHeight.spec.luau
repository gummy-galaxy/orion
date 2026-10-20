local test = require("@std/test")

local geometry = require("@root/geometry")
local getHeaderHeight = require("@root/graph/getHeaderHeight")
local testing = require("@root/testing")

test.case("getHeaderHeight adds the header band only when a group has a header", function(assert)
	local group = testing.group("g", "Group")
	assert.eq(getHeaderHeight(group), geometry.GROUP_HEADER_HEIGHT)
	group.data.header = "   "
	assert.eq(getHeaderHeight(group), geometry.GROUP_HEADER_HEIGHT)
	group.data.header = "# Sprint 14"
	assert.eq(getHeaderHeight(group), geometry.GROUP_HEADER_HEIGHT + geometry.GROUP_HEADER_BAND)
end)
