local json = require("@std/json")

local createId = require("@root/common/createId")
local findPlacement = require("@root/canvas/placement/findPlacement")
local geometry = require("@root/geometry")
local getGroup = require("@root/canvas/groups/getGroup")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function addImage(doc: Doc, label: string, extension: string, canvas: string, group: string?): Item
	assert(label ~= "", "an image needs a label")

	if group then
		getGroup(doc, group)
	end

	local id = createId()
	local item: Item = {
		id = id,
		type = "image",
		position = { x = 0, y = 0 },
		parentId = group,
		width = geometry.IMAGE_SIZE.width,
		height = geometry.IMAGE_SIZE.height,
		data = json.object({ kind = "image", label = label, asset = `{id}.{extension}`, canvas = canvas }),
	}
	item.position = findPlacement(doc, item)
	table.insert(doc.nodes, item)
	return item
end

return addImage
