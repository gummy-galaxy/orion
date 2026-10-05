local test = require("@std/test")

local match = require("@root/match")
local testing = require("@root/testing")

test.case(
	"candidates rank words and repository agreement, excluding notes, linked cards, and done work",
	function(assert)
		local doc = testing.doc({
			testing.task("best", "Release dashboard", "todo", nil, { repo = "flipbook", note = "health" }),
			testing.task("generic", "Release health", "active"),
			testing.task("other", "Release health dashboard", "todo", nil, { repo = "storyteller" }),
			testing.task("linked", "Release health dashboard", "todo", nil, { repo = "flipbook", pr = 1 }),
			testing.task("done", "Release health dashboard", "done", nil, { repo = "flipbook" }),
			testing.task("note", "Release health dashboard", "todo", nil, { itemKind = "note" }),
		})
		local candidates = match.candidates(doc, "Add release health dashboard", "flipbook-labs", "flipbook")
		assert.eq(#candidates, 3)
		assert.eq(candidates[1].id, "best")
		assert.eq(candidates[1].score, 1)
		assert.eq(candidates[2].id, "other")
		assert.eq(candidates[3].id, "generic")
	end
)
