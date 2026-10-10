local test = require("@std/test")

local getPullFields = require("@root/github/getPullFields")

test.case("pull fields include the state needed by synchronization", function(assert)
	assert.strContains(getPullFields(), "baseRefName headRefName")
	assert.strContains(getPullFields(), "statusCheckRollup")
end)
