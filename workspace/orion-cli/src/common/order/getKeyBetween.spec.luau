local test = require("@std/test")

local getKeyBetween = require("@root/common/order/getKeyBetween")
local isOrderKey = require("@root/common/order/isOrderKey")

test.case("getKeyBetween starts in the middle and counts up and down at the ends", function(assert)
	assert.eq(getKeyBetween(nil, nil), "a0")
	assert.eq(getKeyBetween("a0", nil), "a1")
	assert.eq(getKeyBetween("az", nil), "b00")
	assert.eq(getKeyBetween(nil, "a0"), "Zz")
	assert.eq(getKeyBetween(nil, "a0V"), "a0")
end)

test.case("getKeyBetween splits the gap between two keys", function(assert)
	assert.eq(getKeyBetween("a0", "a2"), "a1")
	assert.eq(getKeyBetween("a0", "a1"), "a0V")
	assert.eq(getKeyBetween("a0V", "a1"), "a0l")
	assert.eq(getKeyBetween("a1", "b00"), "a2")
	assert.eq(getKeyBetween("az", "b00"), "azV")
end)

test.case("getKeyBetween keeps room after many keys squeezed into one gap", function(assert)
	local before, after = "a0", "a1"

	for i = 1, 200 do
		local key = getKeyBetween(before, after)
		assert.eq(before < key and key < after, true)
		assert.eq(isOrderKey(key), true)

		if i % 2 == 0 then
			before = key
		else
			after = key
		end
	end
end)

test.case("getKeyBetween stays short when keys are only added at the end", function(assert)
	local key = nil

	for _ = 1, 1000 do
		local nextKey = getKeyBetween(key, nil)
		assert.eq(key == nil or key < nextKey, true)
		key = nextKey
	end

	assert.eq(#(key :: string) <= 3, true)
end)

test.case("getKeyBetween refuses keys out of order or malformed", function(assert)
	assert.throws(function()
		getKeyBetween("a1", "a0")
	end)
	assert.throws(function()
		getKeyBetween("a10", nil)
	end)
	assert.throws(function()
		getKeyBetween("hello", nil)
	end)
end)
