local json = require("@std/json")

local function createFailure(id: json.Value, code: number, message: string): json.Object
	return json.object({
		jsonrpc = "2.0",
		id = if id == nil then json.null else id,
		error = json.object({ code = code, message = message }),
	})
end

return createFailure
