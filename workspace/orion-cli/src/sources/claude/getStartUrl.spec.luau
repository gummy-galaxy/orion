local test = require("@std/test")

local getStartUrl = require("@root/sources/claude/getStartUrl")
local types = require("@root/types")

type Source = types.Source

local SOURCE: Source = { id = "claude", kind = "claude" }

test.case("a start link opens Claude Desktop in the folder with the prompt", function(assert)
	assert.eq(
		getStartUrl(SOURCE, { cwd = "/work/orion", prompt = "Fix it & push" }),
		"claude://code/new?folder=%2Fwork%2Forion&q=Fix%20it%20%26%20push"
	)
end)

test.case("a long prompt is cut to what Desktop keeps", function(assert)
	local url = getStartUrl(SOURCE, { cwd = "/work", prompt = string.rep("a", 20000) })
	assert.eq(#url, #"claude://code/new?folder=%2Fwork&q=" + 14000)
end)

test.case("with no folder, Desktop asks for one", function(assert)
	assert.eq(getStartUrl(SOURCE, { prompt = "Go" }), "claude://code/new?q=Go")
end)
