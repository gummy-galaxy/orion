-- Drops the file and line prefix Luau adds to error messages.
local function cleanErrorMessage(message: unknown): string
	return (tostring(message):gsub("^[^\n]-:%d+: ", "", 1))
end

return cleanErrorMessage
