local path = require("@std/path")
local process = require("@std/process")

local getDataDir = require("@root/platform/getDataDir")
local getPlatform = require("@root/platform/getPlatform")

local function getDefaultDataDir(): path.Path
	return getDataDir(getPlatform(), process.homedir(), process.env)
end

return getDefaultDataDir
