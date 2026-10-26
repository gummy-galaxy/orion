local test = require("@std/test")

local getKeyRepo = require("@root/refs/getKeyRepo")

type KeyRepo = getKeyRepo.KeyRepo

test.case("a pull request key splits into its repository and number", function(assert)
	local repo = getKeyRepo("vocksel/orion#538") :: KeyRepo
	assert.eq(repo.location, "vocksel/orion")
	assert.eq(repo.host, "github.com")
	assert.eq(repo.owner, "vocksel")
	assert.eq(repo.name, "orion")
	assert.eq(repo.suffix, "#538")
end)

test.case("a branch key keeps everything after the first @ as its suffix", function(assert)
	local repo = getKeyRepo("vocksel/orion@agent/fix@2") :: KeyRepo
	assert.eq(repo.location, "vocksel/orion")
	assert.eq(repo.suffix, "@agent/fix@2")
end)

test.case("an Enterprise key keeps its host in the location", function(assert)
	local repo = getKeyRepo("GHE.example.com/team/app#4") :: KeyRepo
	assert.eq(repo.location, "ghe.example.com/team/app")
	assert.eq(repo.host, "ghe.example.com")
end)

test.case("a key with github.com in front locates like one without it", function(assert)
	local repo = getKeyRepo("github.com/vocksel/orion@main") :: KeyRepo
	assert.eq(repo.location, "vocksel/orion")
end)

test.case("keys that don't name a repository have none", function(assert)
	assert.eq(getKeyRepo("ABC-123"), nil)
	assert.eq(getKeyRepo("orion#1"), nil)
	assert.eq(getKeyRepo("vocksel/orion"), nil)
end)
