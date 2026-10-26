-- Reads a --limit option as a positive whole number, or nil when it was left
-- out.
local function parseLimit(value: string?): number?
	if value == nil then
		return nil
	end

	local limit = tonumber(value)
	assert(limit and limit >= 1 and limit % 1 == 0, "limit must be a positive integer")
	return limit
end

return parseLimit
