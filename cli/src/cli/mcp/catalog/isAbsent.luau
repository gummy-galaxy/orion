local json = require("@std/json")

local function isAbsent(value: json.Value): boolean
	return value == nil or value == json.null
end

return isAbsent
