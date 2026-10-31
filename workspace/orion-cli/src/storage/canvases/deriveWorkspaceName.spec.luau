local test = require("@std/test")

local deriveWorkspaceName = require("@root/storage/canvases/deriveWorkspaceName")

test.case("workspace names are derived from labels as lowercase hyphenated words", function(assert)
	assert.eq(deriveWorkspaceName("Focus areas"), "focus-areas")
	assert.eq(deriveWorkspaceName("  Design / QA!  "), "design-qa")
	assert.eq(deriveWorkspaceName("Roblox"), "roblox")
	assert.throwsWith("pass a name: the label has no letters or digits to derive one from", function()
		deriveWorkspaceName("!!!")
	end)
end)
