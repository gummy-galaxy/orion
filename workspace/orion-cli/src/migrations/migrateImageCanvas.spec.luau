local json = require("@std/json")
local test = require("@std/test")

local migrateImageCanvas = require("@root/migrations/migrateImageCanvas")
local types = require("@root/types")

type Item = types.Item

local function image(data: json.Object): Item
	return { id = "picture", type = "image", position = { x = 0, y = 0 }, data = data }
end

test.case("migrateImageCanvas moves an image's workspace to canvas", function(assert)
	local item = image(json.object({ kind = "image", label = "Picture", asset = "a.png", workspace = "planning" }))
	migrateImageCanvas(item)

	assert.eq(item.data.canvas, "planning")
	assert.eq(item.data.workspace, nil)
end)

test.case("migrateImageCanvas keeps a canvas the image already has", function(assert)
	local item = image(json.object({ kind = "image", asset = "a.png", workspace = "old", canvas = "new" }))
	migrateImageCanvas(item)

	assert.eq(item.data.canvas, "new")
	assert.eq(item.data.workspace, nil)
end)
