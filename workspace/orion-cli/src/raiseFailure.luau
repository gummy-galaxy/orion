local types = require("@root/types")

type ErrorCode = types.ErrorCode

-- Turns the failure into its message wherever it becomes text, such as a test's match or an interpolated string.
local FAILURE = table.freeze({
	__tostring = function(failure: { message: string }): string
		return failure.message
	end,
})

-- Raises a failure with a code a script can act on, which --json prints beside the message.
local function raiseFailure(code: ErrorCode, message: string): never
	error(setmetatable({ code = code, message = message }, FAILURE), 0)
end

return raiseFailure
