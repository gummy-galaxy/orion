local path = require("@std/path")

local getAbsolutePath = require("@root/platform/getAbsolutePath")
local platformTypes = require("@root/platform/types")

type Platform = platformTypes.Platform

local function getDataDir(platform: Platform, home: string, environment: { [string]: string }): string
	if platform == "macos" then
		return tostring(path.join(home, "Library", "Application Support", "Orion"))
	elseif platform == "windows" then
		local base = getAbsolutePath(environment.APPDATA) or tostring(path.join(home, "AppData", "Roaming"))
		return tostring(path.join(base, "Orion"))
	end

	local base = getAbsolutePath(environment.XDG_DATA_HOME) or tostring(path.join(home, ".local", "share"))
	return tostring(path.join(base, "orion"))
end

return getDataDir
