local asObject = require("@root/asObject")
local getStringField = require("@root/getStringField")

-- Strips the "file:line: " prefix Luau adds to errors raised with a position,
-- leaving the message. A table raised as an error, such as an operation's
-- rejection, gives its message instead of the table's address.
local function getErrorText(failure: unknown): string
	local object = asObject(failure)
	local message = getStringField(object and object.message)

	if message then
		return message
	end

	return (tostring(failure):gsub("^[^\n]-:%d+: ", "", 1))
end

return getErrorText
