local path = require("@std/path")

local fileNames = require("@root/fileNames")

local function getDocPath(dir: string): string
	return tostring(path.join(dir, fileNames.document))
end

return getDocPath
