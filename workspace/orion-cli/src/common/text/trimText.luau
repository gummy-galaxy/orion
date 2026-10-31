-- The first `limit` characters of `text`, without splitting one in two.
local function trimText(text: string, limit: number): string
	local cut = utf8.offset(text, limit + 1)
	return if cut and cut <= #text then text:sub(1, cut - 1) else text
end

return trimText
