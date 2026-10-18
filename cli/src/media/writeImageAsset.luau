local fs = require("@std/fs")
local path = require("@std/path")

local ensureDirectory = require("@root/platform/ensureDirectory")

return function(dir: string, asset: string, bytes: string)
	local folder = path.join(dir, "assets")
	ensureDirectory(folder)
	local file = path.join(folder, asset)
	assert(not fs.exists(file), `image asset already exists: {asset}`)
	fs.writeStringToFile(file, bytes)
end
