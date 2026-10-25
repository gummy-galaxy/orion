local graphTypes = require("@root/graph/types")
local isComponent = require("@root/graph/isComponent")
local types = require("@root/types")

type Item = types.Item
type ItemFields = graphTypes.ItemFields

-- Sets or clears (with an empty value) a component's shape and color.
local function setLook(item: Item, fields: ItemFields)
	if fields.shape then
		assert(isComponent(item), "only components take a shape")
		item.data.shape = if fields.shape == "" then nil else fields.shape
	end

	if fields.color then
		assert(isComponent(item), "only components and groups take a color")
		item.data.color = if fields.color == "" then nil else fields.color
	end
end

return setLook
