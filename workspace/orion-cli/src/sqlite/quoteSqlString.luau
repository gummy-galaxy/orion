-- Quotes text as an SQL string literal.
local function quoteSqlString(text: string): string
	local escaped = text:gsub("'", "''")
	return `'{escaped}'`
end

return quoteSqlString
