local test = require("@std/test")

local getKey = require("@root/sources/github/refs/getKey")
local getRefFor = require("@root/sources/github/refs/getRefFor")
local testing = require("@root/testing")

test.case("refFor parses pull keys", function(assert)
	local public = getRefFor(testing.task("a", "A", "todo", nil, {
		refs = { { source = "github", kind = "pull", key = "Flipbook-Labs/Flipbook#5" } },
	}))
	assert.eq(public and getKey(public), "flipbook-labs/flipbook#5")
	local private = getRefFor(testing.task("b", "B", "todo", nil, {
		refs = { { source = "github", kind = "pull", key = "github.example.com/Roblox/avatar#2" } },
	}))
	assert.eq(private and getKey(private), "github.example.com/roblox/avatar#2")
	assert.eq(getRefFor(testing.task("c", "C", "todo")), nil)
end)
