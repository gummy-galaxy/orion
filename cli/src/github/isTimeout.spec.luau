local test = require("@std/test")

local isTimeout = require("@root/github/isTimeout")

test.case("timeouts are recognized from gh's error and GitHub's message", function(assert)
	assert.eq(isTimeout("gh api graphql failed: gh: HTTP 502"), true)
	assert.eq(isTimeout("gh api graphql failed: gh: HTTP 504"), true)
	assert.eq(isTimeout("Something went wrong while executing your query. This may be the result of a timeout"), true)
	assert.eq(isTimeout("gh api graphql failed: gh: HTTP 401"), false)
	assert.eq(isTimeout("Could not resolve to a Repository"), false)
end)
