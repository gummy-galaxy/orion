local path = require("@std/path")

local platformTypes = require("@root/platform/types")

type Platform = platformTypes.Platform

-- Returns the value only when it is a non-empty absolute path, so relative environment values are ignored.
local function getAbsolutePath(value: string?): string?
	if value and value ~= "" and path.isAbsolute(value) then
		return value
	end

	return nil
end

local function getDataDir(platform: Platform, home: path.Pathlike, environment: { [string]: string }): path.Path
	if platform == "macos" then
		return path.join(home, "Library", "Application Support", "Orion")
	elseif platform == "windows" then
		local base = getAbsolutePath(environment.APPDATA) or path.join(home, "AppData", "Roaming")
		return path.join(base, "Orion")
	end

	local base = getAbsolutePath(environment.XDG_DATA_HOME) or path.join(home, ".local", "share")
	return path.join(base, "orion")
end

return getDataDir
