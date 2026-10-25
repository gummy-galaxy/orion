local types = require("@root/types")

type ErrorCode = types.ErrorCode

-- The code a failure carries, such as "revision-conflict", or nil when it has none.
local function getErrorCode(failure: unknown): ErrorCode?
	if type(failure) == "table" and type((failure :: any).code) == "string" then
		return (failure :: any).code
	end

	return nil
end

return getErrorCode
