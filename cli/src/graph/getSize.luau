local sizes = require("@root/graph/sizes")
local types = require("@root/types")

type Item = types.Item

-- The size the app draws an item at. Groups use their stored width and height.
local function getSize(item: Item): (number, number)
	if item.type == "task" then
		return sizes.TASK_WIDTH, sizes.TASK_HEIGHT
	end

	return item.width or 320, item.height or 200
end

return getSize
