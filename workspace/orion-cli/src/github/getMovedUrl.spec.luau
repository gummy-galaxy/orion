local test = require("@std/test")

local getMovedUrl = require("@root/github/getMovedUrl")

test.case("a URL under the old name moves to the new one and keeps the rest", function(assert)
	assert.eq(
		getMovedUrl("https://github.com/Vocksel/Orion/pull/12?x=1#top", "vocksel/orion", "gummy-galaxy/orion"),
		"https://github.com/gummy-galaxy/orion/pull/12?x=1#top"
	)
end)

test.case("a URL under another repository stays as it is", function(assert)
	local url = "https://github.com/vocksel/orion-docs/pull/1"
	assert.eq(getMovedUrl(url, "vocksel/orion", "gummy-galaxy/orion"), url)
end)
