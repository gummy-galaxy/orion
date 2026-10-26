local path = require("@std/path")
local process = require("@std/process")

local getDefaultDataDir = require("@root/platform/getDefaultDataDir")

-- The folder that holds every canvas: `ORION_DATA_DIR` when it's set, otherwise
-- the platform's data folder.
local function getDataRoot(): string
	local configured = process.env.ORION_DATA_DIR

	if configured and configured ~= "" then
		return tostring(path.resolve(configured))
	end

	return tostring(getDefaultDataDir())
end

return getDataRoot
