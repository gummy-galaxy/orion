-- Joins a command's variadic words into one text, such as a label, and requires
-- at least one.
local function joinWords(values: { string }, what: string): string
	local text = table.concat(values, " ")
	assert(text ~= "", `missing {what}`)
	return text
end

return joinWords
