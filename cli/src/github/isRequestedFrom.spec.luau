local test = require("@std/test")

local githubTypes = require("@root/github/types")
local isRequestedFrom = require("@root/github/isRequestedFrom")

type PullState = githubTypes.PullState

test.case("requested reviewer comparison ignores case", function(assert)
	local pull: PullState = {
		owner = "vocksel",
		name = "orion",
		number = 1,
		state = "OPEN",
		baseRefName = "main",
		headRefName = "feature",
		draft = false,
		reviewRequests = 1,
		requestedReviewers = { "Vocksel" },
		title = "Title",
		url = "u",
		author = "colleague",
		updatedAt = "now",
		additions = 0,
		deletions = 0,
	}
	assert.eq(isRequestedFrom(pull, "vocksel"), true)
	assert.eq(isRequestedFrom(pull, "colleague"), false)
end)
