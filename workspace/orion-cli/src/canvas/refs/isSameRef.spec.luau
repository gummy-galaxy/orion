local test = require("@std/test")

local isSameRef = require("@root/canvas/refs/isSameRef")
local types = require("@root/types")

type Ref = types.Ref

test.case("refs with ids match by id, whatever their keys say", function(assert)
	local before: Ref = { source = "github", kind = "pull", key = "vocksel/orion#12", id = "R_1#12" }
	local after: Ref = { source = "github", kind = "pull", key = "gummy-galaxy/orion#12", id = "R_1#12" }
	local reused: Ref = { source = "github", kind = "pull", key = "vocksel/orion#12", id = "R_2#12" }

	assert.eq(isSameRef(before, after), true)
	assert.eq(isSameRef(before, reused), false)
end)

test.case("refs without an id on both sides match by case-insensitive key", function(assert)
	local stored: Ref = { source = "github", kind = "pull", key = "Vocksel/Orion#12" }
	local fetched: Ref = { source = "github", kind = "pull", key = "vocksel/orion#12", id = "R_1#12" }
	local other: Ref = { source = "github", kind = "pull", key = "vocksel/orion#13" }

	assert.eq(isSameRef(stored, fetched), true)
	assert.eq(isSameRef(stored, other), false)
end)

test.case("refs of different kinds never match", function(assert)
	local pull: Ref = { source = "github", kind = "pull", key = "vocksel/orion#12", id = "X" }
	local issue: Ref = { source = "github", kind = "issue", key = "vocksel/orion#12", id = "X" }

	assert.eq(isSameRef(pull, issue), false)
end)
