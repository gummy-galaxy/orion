-- Points a URL at a repository's current name, when its path starts with the
-- old owner/name, keeping the rest of it.
local function getMovedUrl(url: string, previous: string, current: string): string
	local origin, path = url:match("^(https?://[^/]+/)([^/]+/[^/#?]+)")

	if not origin or not path or path:lower() ~= previous:lower() then
		return url
	end

	return `{origin}{current}{url:sub(#origin + #path + 1)}`
end

return getMovedUrl
