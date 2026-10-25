-- Joins words into prose, such as "label, note, and ref" or "'true' or 'false'", wrapping each in `quote` when given.
local function formatList(words: { string }, conjunction: string?, quote: string?): string
	local quoted: { string } = {}

	for _, word in words do
		table.insert(quoted, `{quote or ""}{word}{quote or ""}`)
	end

	local last = table.remove(quoted) :: string

	if #quoted == 0 then
		return last
	end

	local joiner = if #quoted == 1 then " " else ", "
	return `{table.concat(quoted, ", ")}{joiner}{conjunction or "and"} {last}`
end

return formatList
