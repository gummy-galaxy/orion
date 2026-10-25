-- Strips the "file:line: " prefix Luau adds to errors raised with a position, leaving the message. A table raised as
-- an error, such as an operation's rejection, gives its message instead of the table's address.
local function getErrorText(failure: unknown): string
	if type(failure) == "table" and type((failure :: any).message) == "string" then
		return (failure :: any).message
	end

	return (tostring(failure):gsub("^[^\n]-:%d+: ", "", 1))
end

return getErrorText
