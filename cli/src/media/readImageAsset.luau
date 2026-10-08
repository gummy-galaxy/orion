local fs = require("@std/fs")
local path = require("@std/path")

local detectImageFormat = require("@root/media/detectImageFormat")

return function(dir: string, asset: string): (string?, string?)
	local stem, suffix = asset:match("^([a-z0-9%-]+)%.([a-z]+)$")
	assert(stem and (suffix == "png" or suffix == "jpg" or suffix == "gif" or suffix == "webp"), "invalid image asset")
	local file = path.join(dir, "assets", asset)
	if not fs.exists(file) or fs.type(file) ~= "file" then
		return nil, nil
	end
	local bytes = fs.readFileToString(file)
	local extension, mime = detectImageFormat(bytes)
	assert(suffix == extension, "invalid image asset")
	return bytes, mime
end
