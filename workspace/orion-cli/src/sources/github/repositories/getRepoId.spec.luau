local json = require("@std/json")
local test = require("@std/test")

local getRepoId = require("@root/sources/github/repositories/getRepoId")

test.case("a repository's id is its database number as a string", function(assert)
	assert.eq(getRepoId(json.object({ databaseId = 1404895435 })), "1404895435")
end)

test.case("a repository with no number has no id", function(assert)
	assert.eq(getRepoId(json.object({ id = "R_kgDOU70Ayw" })), nil)
	assert.eq(getRepoId(nil), nil)
end)
