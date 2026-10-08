local json = require("@std/json")

local function getRequiredString(arguments: json.Object, name: string): string
	local value = arguments[name]
	assert(type(value) == "string" and value ~= "", `missing {name}`)
	return value
end

return getRequiredString
