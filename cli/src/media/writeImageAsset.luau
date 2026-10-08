local fs = require("@std/fs")
local path = require("@std/path")

return function(dir: string, asset: string, bytes: string)
	local folder = path.join(dir, "assets")
	if not fs.exists(folder) then
		fs.createDirectory(folder, { makeParents = true })
	end
	local file = path.join(folder, asset)
	assert(not fs.exists(file), `image asset already exists: {asset}`)
	fs.writeStringToFile(file, bytes)
end
