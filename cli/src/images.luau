local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local graph = require("@root/graph")
local store = require("@root/store")
local types = require("@root/types")

type Item = types.Item

local images = {}
local MAX_BYTES = 5 * 1024 * 1024
local sequence = 0

local function getFormat(bytes: string): (string, string)
	if bytes:sub(1, 8) == string.char(137, 80, 78, 71, 13, 10, 26, 10) then
		return "png", "image/png"
	elseif bytes:sub(1, 3) == string.char(255, 216, 255) then
		return "jpg", "image/jpeg"
	elseif bytes:sub(1, 6) == "GIF87a" or bytes:sub(1, 6) == "GIF89a" then
		return "gif", "image/gif"
	elseif bytes:sub(1, 4) == "RIFF" and bytes:sub(9, 12) == "WEBP" then
		return "webp", "image/webp"
	end
	error("image must be PNG, JPEG, GIF, or WebP")
end

local function validateBytes(bytes: string): (string, string)
	assert(#bytes > 0 and #bytes <= MAX_BYTES, "image must be 5 MB or smaller")
	return getFormat(bytes)
end

local function writeAsset(dir: string, asset: string, bytes: string)
	local folder = path.join(dir, "assets")
	if not fs.exists(folder) then
		fs.createDirectory(folder, { makeParents = true })
	end
	local file = path.join(folder, asset)
	assert(not fs.exists(file), `image asset already exists: {asset}`)
	fs.writeStringToFile(file, bytes)
end

function images.importBytes(dir: string, bytes: string): { asset: string, mime: string }
	local extension, mime = validateBytes(bytes)
	sequence += 1
	local asset = `image-{os.time()}-{process.pid()}-{sequence}.{extension}`
	writeAsset(dir, asset, bytes)
	return { asset = asset, mime = mime }
end

function images.readBytes(dir: string, asset: string): (string?, string?)
	local stem, suffix = asset:match("^([a-z0-9%-]+)%.([a-z]+)$")
	assert(stem and (suffix == "png" or suffix == "jpg" or suffix == "gif" or suffix == "webp"), "invalid image asset")
	local file = path.join(dir, "assets", asset)
	if not fs.exists(file) or fs.type(file) ~= "file" then
		return nil, nil
	end
	local bytes = fs.readFileToString(file)
	local extension, mime = validateBytes(bytes)
	assert(suffix == extension, "invalid image asset")
	return bytes, mime
end

function images.add(dir: string, workspace: string, file: string, label: string?, group: string?): Item
	assert(fs.exists(file) and fs.type(file) == "file", `image file not found: {file}`)
	local size = fs.metadata(file).size
	assert(size > 0 and size <= MAX_BYTES, "image must be 5 MB or smaller")
	local bytes = fs.readFileToString(file)
	local extension = validateBytes(bytes)
	local name = label or ((path.basename(file) or ""):gsub("%.[^.]+$", ""))
	local added: Item? = nil
	store.transaction(dir, function(doc)
		local item = graph.addImage(doc, name, extension, workspace, group)
		writeAsset(dir, item.data.asset :: string, bytes)
		added = item
	end)
	return added :: Item
end

return table.freeze(images)
