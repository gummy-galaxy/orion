local test = require("@std/test")

local findRef = require("@root/refs/findRef")
local githubTypes = require("@root/github/types")
local setPullRef = require("@root/github/setPullRef")
local testing = require("@root/testing")

type PullState = githubTypes.PullState

test.case("setPullRef records source status and branch details", function(assert)
	local item = testing.task("a", "A", "todo")
	local pull: PullState = {
		owner = "Vocksel",
		name = "Orion",
		number = 12,
		state = "OPEN",
		baseRefName = "main",
		headRefName = "feature/A",
		draft = true,
		reviewRequests = 0,
		requestedReviewers = {},
		title = "Work",
		url = "https://github.com/Vocksel/Orion/pull/12",
		author = "vocksel",
		updatedAt = "now",
		additions = 1,
		deletions = 2,
		branch = "feature/A",
	}
	setPullRef(item, pull, "gh-vocksel", "vocksel", "now")
	local ref = findRef(item, "pull")
	assert.eq(ref and ref.key, "Vocksel/Orion#12")
	assert.eq(ref and ref.source, "gh-vocksel")
	assert.eq(ref and ref.status, "draft")
	assert.eq(ref and ref.isDone, false)
	assert.eq(ref and ref.details and ref.details.branch, "feature/A")
	setPullRef(item, pull, "github", "vocksel", "later")
	assert.eq((findRef(item, "pull") :: any).source, "gh-vocksel")
end)
