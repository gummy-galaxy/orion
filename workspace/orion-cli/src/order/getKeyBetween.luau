local digits = require("@root/order/digits")
local getIntegerLength = require("@root/order/getIntegerLength")
local isOrderKey = require("@root/order/isOrderKey")

local BASE = #digits
local ZERO = digits:sub(1, 1)
local LAST = digits:sub(BASE, BASE)
local FIRST_KEY = `a{ZERO}`
local SMALLEST_INTEGER = `A{string.rep(ZERO, 26)}`

local function getDigit(index: number): string
	return digits:sub(index + 1, index + 1)
end

local function getIndex(digit: string): number
	return (assert(digits:find(digit, 1, true), `"{digit}" isn't an order key digit`)) - 1
end

-- A fraction strictly between `a` and `b`, where an empty `a` is zero and a nil
-- `b` is one. Neither ends in zero.
local function getMidpoint(a: string, b: string?): string
	if b then
		local shared = 0

		while (if shared < #a then a:sub(shared + 1, shared + 1) else ZERO) == b:sub(shared + 1, shared + 1) do
			shared += 1
		end

		if shared > 0 then
			return b:sub(1, shared) .. getMidpoint(a:sub(shared + 1), b:sub(shared + 1))
		end
	end

	local low = if a ~= "" then getIndex(a:sub(1, 1)) else 0
	local high = if b then getIndex(b:sub(1, 1)) else BASE

	if high - low > 1 then
		return getDigit(math.floor((low + high) / 2 + 0.5))
	elseif b and #b > 1 then
		return b:sub(1, 1)
	end

	return getDigit(low) .. getMidpoint(a:sub(2), nil)
end

local function splitKey(key: string): (string, string)
	local length = assert(getIntegerLength(key:sub(1, 1)), `"{key}" isn't an order key`)
	return key:sub(1, length), key:sub(length + 1)
end

-- The next integer up, or nil past the largest.
local function incrementInteger(integer: string): string?
	local head = integer:sub(1, 1)
	local body = integer:sub(2):split("")

	for i = #body, 1, -1 do
		local index = getIndex(body[i]) + 1

		if index < BASE then
			body[i] = getDigit(index)
			return head .. table.concat(body)
		end

		body[i] = ZERO
	end

	if head == "Z" then
		return FIRST_KEY
	elseif head == "z" then
		return nil
	end

	local nextHead = string.char(string.byte(head) + 1)

	if nextHead > "a" then
		table.insert(body, ZERO)
	else
		table.remove(body)
	end

	return nextHead .. table.concat(body)
end

-- The next integer down, or nil past the smallest.
local function decrementInteger(integer: string): string?
	local head = integer:sub(1, 1)
	local body = integer:sub(2):split("")

	for i = #body, 1, -1 do
		local index = getIndex(body[i]) - 1

		if index >= 0 then
			body[i] = getDigit(index)
			return head .. table.concat(body)
		end

		body[i] = LAST
	end

	if head == "a" then
		return `Z{LAST}`
	elseif head == "A" then
		return nil
	end

	local nextHead = string.char(string.byte(head) - 1)

	if nextHead < "Z" then
		table.insert(body, LAST)
	else
		table.remove(body)
	end

	return nextHead .. table.concat(body)
end

--[[
	An order key that sorts after `before` and before `after`, either of which
	can be nil for an open end. Keys compare as plain strings and never run out
	of room between two of them. Keys made only at the ends stay short, since
	they count up or down an integer part, and only keys squeezed between two
	others grow a fraction. Follows David Greenspan's fractional indexing, as in
	the `fractional-indexing` package.
]]
local function getKeyBetween(before: string?, after: string?): string
	assert(before == nil or isOrderKey(before), `"{before}" isn't an order key`)
	assert(after == nil or isOrderKey(after), `"{after}" isn't an order key`)
	assert(before == nil or after == nil or (before :: string) < (after :: string), "keys must be in order")

	if before == nil and after == nil then
		return FIRST_KEY
	elseif before == nil then
		local integer, fraction = splitKey(after :: string)

		if integer == SMALLEST_INTEGER then
			return integer .. getMidpoint("", fraction)
		elseif fraction ~= "" then
			return integer
		end

		return assert(decrementInteger(integer), "ran out of order keys")
	elseif after == nil then
		local integer, fraction = splitKey(before)
		return incrementInteger(integer) or (integer .. getMidpoint(fraction, nil))
	end

	local beforeInteger, beforeFraction = splitKey(before :: string)
	local afterInteger, afterFraction = splitKey(after :: string)

	if beforeInteger == afterInteger then
		return beforeInteger .. getMidpoint(beforeFraction, afterFraction)
	end

	local integer = incrementInteger(beforeInteger)

	if integer and integer < (after :: string) then
		return integer
	end

	return beforeInteger .. getMidpoint(beforeFraction, nil)
end

return getKeyBetween
