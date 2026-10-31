local json = require("@std/json")

local function getString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

return getString
