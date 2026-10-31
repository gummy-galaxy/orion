local test = require("@std/test")

local getGithubId = require("@root/sources/github/refs/getGithubId")

test.case("a GitHub id is the repository id and the ref's number or branch", function(assert)
	assert.eq(getGithubId("R_1", "#12"), "R_1#12")
	assert.eq(getGithubId("R_1", "@agent/fix", "github.com"), "R_1@agent/fix")
end)

test.case("an Enterprise id keeps its host in front", function(assert)
	assert.eq(getGithubId("R_1", "#12", "GHE.example.com"), "ghe.example.com/R_1#12")
end)
