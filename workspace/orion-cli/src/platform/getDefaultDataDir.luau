local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local getDataDir = require("@root/platform/getDataDir")
local platformTypes = require("@root/platform/types")

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

local function getDefaultDataDir(): path.Path
	return getDataDir(getPlatform(), process.homedir(), process.env)
end

return getDefaultDataDir
