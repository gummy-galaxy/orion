local system = require("@std/system")

local platformTypes = require("@root/common/platform/types")

type Platform = platformTypes.Platform

-- Lute reports the OS only as a string and per-platform booleans, so name the
-- platforms Orion supports.
local function getPlatform(): Platform
	if system.win32 then
		return "windows"
	elseif system.macos then
		return "macos"
	end

	return "linux"
end

return getPlatform
