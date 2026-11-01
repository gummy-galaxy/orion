local getBuild = require("@root/common/getBuild")

-- The version and commit this build came from, such as 0.1.0+e87813e. `orion
-- --version` and the MCP server both report it.
local function getVersion(): string
	local build = getBuild()

	return `{build.version}+{build.commit}`
end

return getVersion
