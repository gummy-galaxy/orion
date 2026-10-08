local process = require("@std/process")

local getDataDir = require("@root/platform/getDataDir")
local getPlatform = require("@root/platform/getPlatform")

local function getDefaultDataDir(): string
	return getDataDir(getPlatform(), tostring(process.homedir()), process.env)
end

return getDefaultDataDir
