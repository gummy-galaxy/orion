local test = require("@std/test")

local parseSort = require("@root/canvas/query/parseSort")

test.case("reads fields in order, descending with a leading dash", function(assert)
	local keys = parseSort("status, -label,pr")
	assert.eq(#keys, 3)
	assert.eq(keys[1].field, "status")
	assert.eq(keys[1].isDescending, false)
	assert.eq(keys[2].field, "label")
	assert.eq(keys[2].isDescending, true)
	assert.eq(keys[3].field, "pr")
	assert.eq(keys[3].isDescending, false)
end)

test.case("refuses unknown fields and empty keys", function(assert)
	assert.throwsWith("sort: unknown field 'owner'", function()
		parseSort("label,owner")
	end)

	for _, input in { "", "label,", ",label", "-", "label,,pr" } do
		assert.throwsWith("sort: expected a field, such as `label` or `-status`", function()
			parseSort(input)
		end)
	end
end)
