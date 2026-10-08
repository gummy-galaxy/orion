local path = require("@std/path")

local function getCursorConfigPath(home: path.Pathlike): path.Path
	return path.join(home, ".cursor", "mcp.json")
end

return getCursorConfigPath
