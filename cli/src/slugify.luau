local MAX_LENGTH = 32

-- Turns text into a lowercase hyphenated id of at most `maxLength` characters. A long slug is cut at the last
-- word boundary that fits, and only mid-word when its first word alone is too long.
local function slugify(text: string, maxLength: number?, fallback: string?): string
	local limit = maxLength or MAX_LENGTH
	local value = text:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")

	if #value > limit then
		local cut = value:sub(1, limit + 1):match("^(.*)%-")
		value = if cut and cut ~= "" then cut else value:sub(1, limit)
	end

	return if value == "" then fallback or "item" else value
end

return slugify
