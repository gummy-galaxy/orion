local path = require("@std/path")

local fileNames = require("@root/fileNames")

local function getLogPath(dir: string): string
	return tostring(path.join(dir, fileNames.log))
end

return getLogPath
