local fs = require("@std/fs")
local path = require("@std/path")

local graph = require("@root/graph")
local imageAssets = require("@root/media/imageAssets")
local imageFormat = require("@root/media/imageFormat")
local store = require("@root/store")
local types = require("@root/types")

type Item = types.Item

return function(dir: string, workspace: string, file: string, label: string?, group: string?): Item
	assert(fs.exists(file) and fs.type(file) == "file", `image file not found: {file}`)
	local size = fs.metadata(file).size
	assert(size > 0 and size <= imageFormat.maxBytes, "image must be 5 MB or smaller")
	local bytes = fs.readFileToString(file)
	local extension = imageFormat.detect(bytes)
	local name = label or ((path.basename(file) or ""):gsub("%.[^.]+$", ""))
	local added: Item? = nil
	store.transaction(dir, function(doc)
		local item = graph.addImage(doc, name, extension, workspace, group)
		imageAssets.write(dir, item.data.asset :: string, bytes)
		added = item
	end)
	return added :: Item
end
