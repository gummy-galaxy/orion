local buildInfo = require("@root/buildInfo")

-- The version and commit this build came from, such as 0.1.0+e87813e. `orion --version` and the MCP server
-- both report it.
local function getVersion(): string
	return `{buildInfo.version}+{buildInfo.commit}`
end

return getVersion
