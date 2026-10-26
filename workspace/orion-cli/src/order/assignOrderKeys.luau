local getKeysBetween = require("@root/order/getKeysBetween")
local isOrderKey = require("@root/order/isOrderKey")

-- The positions of the longest run of strictly increasing keys, in order,
-- skipping missing ones. Patience sorting.
local function findKept(keys: { [number]: string? }, count: number): { number }
	local tails: { number } = {}
	local previous: { [number]: number } = {}

	for position = 1, count do
		local key = keys[position]

		if key then
			local low, high = 1, #tails + 1

			while low < high do
				local middle = (low + high) // 2

				if (keys[tails[middle]] :: string) < key then
					low = middle + 1
				else
					high = middle
				end
			end

			previous[position] = tails[low - 1]
			tails[low] = position
		end
	end

	local kept: { number } = {}
	local position = tails[#tails]

	while position do
		table.insert(kept, 1, position)
		position = previous[position]
	end

	return kept
end

-- Gives the entries from `first` to `last` new keys between `before` and
-- `after`.
local function fill(assigned: { string }, first: number, last: number, before: string?, after: string?)
	for offset, key in getKeysBetween(before, after, last - first + 1) do
		assigned[first + offset - 1] = key
	end
end

--[[
	Order keys for `count` entries in order, given the key each one had before,
	if any. As many entries as can keep their keys do, so moving or adding one
	entry gives only that entry a new key, and the rest get keys between the
	kept keys around them. Two entries that came back with the same key, such as
	from a merge, keep one of them.
]]
local function assignOrderKeys(previous: { [number]: string? }, count: number): { string }
	local keys: { [number]: string? } = {}

	for position = 1, count do
		local key = previous[position]
		keys[position] = if isOrderKey(key) then key else nil
	end

	local assigned: { string } = {}
	local before: string? = nil
	local first = 1

	for _, position in findKept(keys, count) do
		local key = keys[position] :: string
		fill(assigned, first, position - 1, before, key)
		assigned[position] = key
		before = key
		first = position + 1
	end

	fill(assigned, first, count, before, nil)

	return assigned
end

return assignOrderKeys
