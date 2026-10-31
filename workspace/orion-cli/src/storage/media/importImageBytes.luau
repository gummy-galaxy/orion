local process = require("@std/process")

local detectImageFormat = require("@root/storage/media/detectImageFormat")
local writeImageAsset = require("@root/storage/media/writeImageAsset")

local sequence = 0

return function(dir: string, bytes: string): { asset: string, mime: string }
	local extension, mime = detectImageFormat(bytes)
	sequence += 1
	local asset = `image-{os.time()}-{process.pid()}-{sequence}.{extension}`
	writeImageAsset(dir, asset, bytes)
	return { asset = asset, mime = mime }
end
