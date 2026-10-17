local fs = require("@std/fs")
local path = require("@std/path")

return function(dir: string, asset: string): boolean
	local file = path.join(dir, "assets", asset)

	return fs.exists(file) and fs.type(file) == "file"
end
