local json = require("@std/json")
local test = require("@std/test")

local findSameRef = require("@root/refs/findSameRef")
local testing = require("@root/testing")

test.case("findSameRef finds a card's ref by id after its key changed", function(assert)
	local item = testing.task(
		"a",
		"A",
		"active",
		nil,
		json.object({
			refs = { json.object({ source = "github", kind = "pull", key = "vocksel/orion#12", id = "R_1#12" }) },
		})
	)

	local found = findSameRef(item, { source = "github", kind = "pull", key = "gummy-galaxy/orion#12", id = "R_1#12" })

	assert.eq(if found then found.key else nil, "vocksel/orion#12")
	assert.eq(findSameRef(item, { source = "github", kind = "pull", key = "vocksel/orion#12", id = "R_2#12" }), nil)
end)
