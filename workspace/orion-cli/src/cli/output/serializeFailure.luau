local json = require("@std/json")

local getErrorCode = require("@root/common/errors/getErrorCode")
local getErrorText = require("@root/common/errors/getErrorText")

-- A failure as {"error": {"code": …, "message": …}}, leaving the code out
-- when the failure has none.
local function serializeFailure(failure: unknown): string
	return json.serialize(
		json.object({ error = json.object({ code = getErrorCode(failure), message = getErrorText(failure) }) })
	)
end

return serializeFailure
