local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local imageFormat = require("@root/media/imageFormat")

local imageAssets = {}
local sequence = 0

function imageAssets.write(dir: string, asset: string, bytes: string)
	local folder = path.join(dir, "assets")
	if not fs.exists(folder) then
		fs.createDirectory(folder, { makeParents = true })
	end
	local file = path.join(folder, asset)
	assert(not fs.exists(file), `image asset already exists: {asset}`)
	fs.writeStringToFile(file, bytes)
end

function imageAssets.importBytes(dir: string, bytes: string): { asset: string, mime: string }
	local extension, mime = imageFormat.detect(bytes)
	sequence += 1
	local asset = `image-{os.time()}-{process.pid()}-{sequence}.{extension}`
	imageAssets.write(dir, asset, bytes)
	return { asset = asset, mime = mime }
end

function imageAssets.readBytes(dir: string, asset: string): (string?, string?)
	local stem, suffix = asset:match("^([a-z0-9%-]+)%.([a-z]+)$")
	assert(stem and (suffix == "png" or suffix == "jpg" or suffix == "gif" or suffix == "webp"), "invalid image asset")
	local file = path.join(dir, "assets", asset)
	if not fs.exists(file) or fs.type(file) ~= "file" then
		return nil, nil
	end
	local bytes = fs.readFileToString(file)
	local extension, mime = imageFormat.detect(bytes)
	assert(suffix == extension, "invalid image asset")
	return bytes, mime
end

return table.freeze(imageAssets)
