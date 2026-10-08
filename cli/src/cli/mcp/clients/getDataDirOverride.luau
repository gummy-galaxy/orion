local path = require("@std/path")

-- Clients start the server with their own environment, so pass along a custom data folder.
local function getDataDirOverride(environment: { [string]: string }): string?
	local configured = environment.ORION_DATA_DIR
	return if configured and configured ~= "" then tostring(path.resolve(configured)) else nil
end

return getDataDirOverride
