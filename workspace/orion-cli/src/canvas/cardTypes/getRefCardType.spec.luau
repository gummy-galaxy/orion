local json = require("@std/json")
local test = require("@std/test")

local getRefCardType = require("@root/canvas/cardTypes/getRefCardType")

local function ref(fields: { [string]: string }): any
	return json.object(fields :: any)
end

test.case("getRefCardType reads the type a ref's adapter recorded", function(assert)
	assert.eq(
		getRefCardType(ref({ source = "figma", kind = "issue", key = "ABC-1", type = "figma.frame" })),
		"figma.frame"
	)
end)

test.case("getRefCardType reads older refs by their kind", function(assert)
	assert.eq(getRefCardType(ref({ source = "github", kind = "pull", key = "vocksel/orion#12" })), "pr")
	assert.eq(getRefCardType(ref({ source = "github", kind = "issue", key = "vocksel/orion#3" })), "placeholder")
	assert.eq(getRefCardType(ref({ source = "jira", kind = "issue", key = "ORN-12" })), "step")
	assert.eq(getRefCardType(ref({ source = "hop", kind = "branch", key = "orion:feature/a" })), "step")
	assert.eq(getRefCardType(ref({ source = "web", kind = "page", key = "example.com" })), nil)
end)
