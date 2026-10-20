local json = require("@std/json")

local createId = require("@root/graph/createId")
local geometry = require("@root/geometry")
local getGroup = require("@root/graph/getGroup")
local getNextSlot = require("@root/graph/getNextSlot")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function addImage(doc: Doc, label: string, extension: string, workspace: string, group: string?): Item
	assert(label ~= "", "an image needs a label")

	if group then
		getGroup(doc, group)
	end

	local id = createId()
	local item: Item = {
		id = id,
		type = "image",
		position = getNextSlot(doc, group),
		parentId = group,
		width = geometry.IMAGE_SIZE.width,
		height = geometry.IMAGE_SIZE.height,
		data = json.object({ kind = "image", label = label, asset = `{id}.{extension}`, workspace = workspace }),
	}
	table.insert(doc.nodes, item)
	return item
end

return addImage
