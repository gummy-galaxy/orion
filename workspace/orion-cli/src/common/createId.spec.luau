local test = require("@std/test")

local createId = require("@root/common/createId")

test.case("createId makes a different version 4 UUID each time", function(assert)
	local seen: { [string]: boolean } = {}

	for _ = 1, 100 do
		local id = createId()
		assert.eq(
			id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil,
			true
		)
		assert.eq(seen[id], nil)
		seen[id] = true
	end
end)
