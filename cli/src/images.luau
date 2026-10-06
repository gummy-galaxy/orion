local fs = require("@std/fs")
local path = require("@std/path")

local graph = require("@root/graph")
local store = require("@root/store")
local types = require("@root/types")

type Item = types.Item

local images = {}
local MAX_BYTES = 5 * 1024 * 1024

local function extension(bytes: string): string
	if bytes:sub(1, 8) == string.char(137, 80, 78, 71, 13, 10, 26, 10) then
		return "png"
	elseif bytes:sub(1, 3) == string.char(255, 216, 255) then
		return "jpg"
	elseif bytes:sub(1, 6) == "GIF87a" or bytes:sub(1, 6) == "GIF89a" then
		return "gif"
	elseif bytes:sub(1, 4) == "RIFF" and bytes:sub(9, 12) == "WEBP" then
		return "webp"
	end
	error("image must be PNG, JPEG, GIF, or WebP")
end

function images.add(dir: string, workspace: string, file: string, label: string?, group: string?): Item
	assert(fs.exists(file), `image file not found: {file}`)
	local size = fs.metadata(file).size
	assert(size > 0 and size <= MAX_BYTES, "image must be 5 MB or smaller")
	local kind = extension(fs.readFileToString(file))
	local name = label or ((path.basename(file) or ""):gsub("%.[^.]+$", ""))
	local added: Item? = nil
	store.transaction(dir, function(doc)
		local item = graph.addImage(doc, name, kind, workspace, group)
		local folder = path.join(dir, "assets")
		if not fs.exists(folder) then
			fs.createDirectory(folder, { makeParents = true })
		end
		fs.copy(file, path.join(folder, item.data.asset :: string))
		added = item
	end)
	return added :: Item
end

return images
