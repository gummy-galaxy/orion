local test = require("@std/test")

local getListFields = require("@root/sources/github/pulls/getListFields")

test.case("list fields leave out merge state, checks, and reviews", function(assert)
	assert.strContains(getListFields(), "baseRefName headRefName")
	assert.eq(getListFields():find("mergeable", 1, true), nil)
	assert.eq(getListFields():find("statusCheckRollup", 1, true), nil)
	assert.eq(getListFields():find("reviewRequests", 1, true), nil)
end)
