local test = require("@std/test")

local getHeaderHeight = require("@root/graph/getHeaderHeight")
local sizes = require("@root/graph/sizes")
local testing = require("@root/testing")

test.case("getHeaderHeight adds the header band only when a group has a header", function(assert)
	local group = testing.group("g", "Group")
	assert.eq(getHeaderHeight(group), sizes.GROUP_HEADER_HEIGHT)
	group.data.header = "   "
	assert.eq(getHeaderHeight(group), sizes.GROUP_HEADER_HEIGHT)
	group.data.header = "# Sprint 14"
	assert.eq(getHeaderHeight(group), sizes.GROUP_HEADER_HEIGHT + sizes.GROUP_HEADER_BAND)
end)
