local path = require("@std/path")

local fileNames = require("@root/fileNames")

-- A canvas folder's SQLite index, which `openCanvasIndex` builds from its
-- files.
local function getIndexPath(dir: string): string
	return tostring(path.join(dir, fileNames.index))
end

return getIndexPath
