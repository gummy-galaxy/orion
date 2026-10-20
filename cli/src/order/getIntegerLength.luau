--[[
	How many characters an order key's integer part takes, head included, from its head. `a` to `z` head integers
	of two to 27 characters that count up, and `Z` down to `A` head ones that count down below them. Nil for any
	other head.
]]
local function getIntegerLength(head: string): number?
	local byte = string.byte(head)

	if byte == nil then
		return nil
	elseif byte >= string.byte("a") and byte <= string.byte("z") then
		return byte - string.byte("a") + 2
	elseif byte >= string.byte("A") and byte <= string.byte("Z") then
		return string.byte("Z") - byte + 2
	end

	return nil
end

return getIntegerLength
