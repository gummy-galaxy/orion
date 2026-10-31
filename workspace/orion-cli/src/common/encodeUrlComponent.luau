-- Percent-encodes text for a URL's query value, leaving only the characters
-- JavaScript's encodeURIComponent leaves.
local function encodeUrlComponent(text: string): string
	return (
		text:gsub("[^%w%-_%.!~%*'%(%)]", function(character)
			return string.format("%%%02X", string.byte(character))
		end)
	)
end

return encodeUrlComponent
