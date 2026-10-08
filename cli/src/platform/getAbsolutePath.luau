local path = require("@std/path")

-- Returns the value only when it is a non-empty absolute path, so relative environment values are ignored.
local function getAbsolutePath(value: string?): string?
	if value and value ~= "" and path.isAbsolute(value) then
		return value
	end

	return nil
end

return getAbsolutePath
