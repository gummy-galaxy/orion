local getKeyBetween = require("@root/common/order/getKeyBetween")

--[[
	`count` order keys in order, all after `before` and before `after`, either
	of which can be nil for an open end. Keys between two bounds split the gap
	in halves, so filling it with many keys keeps them short.
]]
local function getKeysBetween(before: string?, after: string?, count: number): { string }
	if count <= 0 then
		return {}
	elseif count == 1 then
		return { getKeyBetween(before, after) }
	end

	local keys: { string } = {}

	if after == nil then
		local key = before

		for _ = 1, count do
			key = getKeyBetween(key, nil)
			table.insert(keys, key :: string)
		end

		return keys
	elseif before == nil then
		local key = after

		for _ = 1, count do
			key = getKeyBetween(nil, key)
			table.insert(keys, 1, key :: string)
		end

		return keys
	end

	local middle = math.floor(count / 2)
	local key = getKeyBetween(before, after)
	local below = getKeysBetween(before, key, middle)
	local above = getKeysBetween(key, after, count - middle - 1)

	table.move(below, 1, #below, 1, keys)
	table.insert(keys, key)
	table.move(above, 1, #above, #keys + 1, keys)

	return keys
end

return getKeysBetween
