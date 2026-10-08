local path = require("@std/path")

local function getCursorConfigPath(home: string): string
	return tostring(path.join(home, ".cursor", "mcp.json"))
end

return getCursorConfigPath
