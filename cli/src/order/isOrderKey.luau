local digits = require("@root/order/digits")
local getIntegerLength = require("@root/order/getIntegerLength")

local SMALLEST_INTEGER = `A{string.rep(digits:sub(1, 1), 26)}`

-- Whether a value is an order key `getKeyBetween` could have made: an integer part, then a fraction without a
-- trailing zero.
local function isOrderKey(value: unknown): boolean
	if type(value) ~= "string" or value == "" then
		return false
	end

	local key = value :: string
	local length = getIntegerLength(key:sub(1, 1))

	if length == nil or #key < length or key == SMALLEST_INTEGER then
		return false
	end

	for i = 2, #key do
		if not digits:find(key:sub(i, i), 1, true) then
			return false
		end
	end

	return #key == length or key:sub(-1) ~= digits:sub(1, 1)
end

return isOrderKey
