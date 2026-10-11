-- Strips the "file:line: " prefix Luau adds to errors raised with a position, leaving the message.
local function getErrorText(failure: unknown): string
	return (tostring(failure):gsub("^[^\n]-:%d+: ", "", 1))
end

return getErrorText
