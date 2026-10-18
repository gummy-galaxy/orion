-- Identifies a link by its ends, which is how the document names one.
local function linkKey(from: string, to: string): string
	return `{from}\0{to}`
end

return linkKey
