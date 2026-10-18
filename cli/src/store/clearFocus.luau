local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")

local function clearFocus(dir: string)
	local file = tostring(path.join(dir, fileNames.focus))

	if fs.exists(file) then
		fs.remove(file)
	end
end

return clearFocus
