local test = require("@std/test")

local getGithubKey = require("@root/sources/github/refs/getGithubKey")

test.case("getGithubKey preserves case and prefixes nonstandard hosts", function(assert)
	assert.eq(getGithubKey("Vocksel", "Orion", "#12"), "Vocksel/Orion#12")
	assert.eq(
		getGithubKey("Roblox", "Avatar", "@feature/A", "github.example.com"),
		"github.example.com/Roblox/Avatar@feature/A"
	)
end)
