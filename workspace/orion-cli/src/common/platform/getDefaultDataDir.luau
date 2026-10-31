local path = require("@std/path")
local process = require("@std/process")

local getDataDir = require("@root/common/platform/getDataDir")
local getPlatform = require("@root/common/platform/getPlatform")

local function getDefaultDataDir(): path.Path
	return getDataDir(getPlatform(), process.homedir(), process.env)
end

return getDefaultDataDir
