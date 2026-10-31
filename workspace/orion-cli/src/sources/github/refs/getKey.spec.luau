local test = require("@std/test")

local getKey = require("@root/sources/github/refs/getKey")

test.case("keys normalize owner, repo, and host", function(assert)
	assert.eq(getKey({ owner = "Vocksel", name = "Orion", number = 54 }), "vocksel/orion#54")
	assert.eq(
		getKey({ owner = "Vocksel", name = "Orion", number = 54, host = "github.example.com" }),
		"github.example.com/vocksel/orion#54"
	)
end)
