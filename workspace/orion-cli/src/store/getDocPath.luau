local path = require("@std/path")

local fileNames = require("@root/fileNames")

-- A canvas folder's `canvas.json`. Every write replaces it last, so a change to it marks a finished write.
local function getDocPath(dir: string): string
	return tostring(path.join(dir, fileNames.document))
end

return getDocPath
