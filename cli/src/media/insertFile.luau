local fs = require("@std/fs")
local path = require("@std/path")

local detectImageFormat = require("@root/media/detectImageFormat")
local graph = require("@root/graph")
local store = require("@root/store")
local types = require("@root/types")
local validateImageSize = require("@root/media/validateImageSize")
local writeImageAsset = require("@root/media/writeImageAsset")

type Item = types.Item

return function(dir: string, workspace: string, file: string, label: string?, group: string?): Item
	assert(fs.exists(file) and fs.type(file) == "file", `image file not found: {file}`)
	validateImageSize(fs.metadata(file).size)
	local bytes = fs.readFileToString(file)
	local extension = detectImageFormat(bytes)
	local name = label or ((path.basename(file) or ""):gsub("%.[^.]+$", ""))
	local added: Item? = nil
	store.transaction(dir, function(doc)
		local item = graph.addImage(doc, name, extension, workspace, group)
		writeImageAsset(dir, item.data.asset :: string, bytes)
		added = item
	end)
	return added :: Item
end
