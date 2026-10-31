local test = require("@std/test")

local assignOrderKeys = require("@root/common/order/assignOrderKeys")

local function isSorted(keys: { string }): boolean
	for i = 2, #keys do
		if keys[i - 1] >= keys[i] then
			return false
		end
	end

	return true
end

test.case("assignOrderKeys gives new entries keys in order", function(assert)
	local keys = assignOrderKeys({}, 3)
	assert.eq(#keys, 3)
	assert.eq(isSorted(keys), true)
end)

test.case("assignOrderKeys keeps every key that's still in order", function(assert)
	local keys = assignOrderKeys({ "a0", "a1", nil, "a2" }, 5)
	assert.eq(keys[1], "a0")
	assert.eq(keys[2], "a1")
	assert.eq(keys[4], "a2")
	assert.eq(isSorted(keys), true)
end)

test.case("assignOrderKeys gives only a moved entry a new key", function(assert)
	local keys = assignOrderKeys({ "a3", "a0", "a1", "a2" }, 4)
	assert.eq(keys[2], "a0")
	assert.eq(keys[3], "a1")
	assert.eq(keys[4], "a2")
	assert.eq(keys[1] < "a0", true)
end)

test.case("assignOrderKeys replaces repeated and malformed keys", function(assert)
	local keys = assignOrderKeys({ "a0", "a0", "not a key", "a1" }, 4)
	assert.eq(keys[1] == "a0" or keys[2] == "a0", true)
	assert.eq(keys[4], "a1")
	assert.eq(isSorted(keys), true)
end)
