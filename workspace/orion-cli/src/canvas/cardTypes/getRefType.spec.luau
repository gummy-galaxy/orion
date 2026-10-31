local json = require("@std/json")
local test = require("@std/test")

local getRefType = require("@root/canvas/cardTypes/getRefType")

local function ref(fields: { [string]: string }): any
	return json.object(fields :: any)
end

test.case("getRefType reads the type a ref's adapter recorded", function(assert)
	assert.eq(getRefType(ref({ source = "figma", kind = "issue", key = "ABC-1", type = "figma.frame" })), "figma.frame")
end)

test.case("getRefType reads older refs by their kind", function(assert)
	assert.eq(getRefType(ref({ source = "github", kind = "pull", key = "vocksel/orion#12" })), "pr")
	assert.eq(getRefType(ref({ source = "github", kind = "issue", key = "vocksel/orion#3" })), "placeholder")
	assert.eq(getRefType(ref({ source = "jira", kind = "issue", key = "ORN-12" })), "step")
	assert.eq(getRefType(ref({ source = "hop", kind = "branch", key = "orion:feature/a" })), "step")
	assert.eq(getRefType(ref({ source = "web", kind = "page", key = "example.com" })), nil)
end)
