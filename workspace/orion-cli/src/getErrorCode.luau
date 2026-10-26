local asObject = require("@root/asObject")
local getStringField = require("@root/getStringField")
local types = require("@root/types")

type ErrorCode = types.ErrorCode

-- The code a failure carries, such as "revision-conflict", or nil when it has
-- none.
local function getErrorCode(failure: unknown): ErrorCode?
	local object = asObject(failure)

	return getStringField(object and object.code) :: ErrorCode?
end

return getErrorCode
