local json = require("@std/json")

local function createSuccess(id: json.Value, result: json.Object): json.Object
	return json.object({ jsonrpc = "2.0", id = id, result = result })
end

return createSuccess
