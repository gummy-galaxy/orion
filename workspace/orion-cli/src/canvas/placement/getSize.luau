local estimateTaskHeight = require("@root/canvas/placement/estimateTaskHeight")
local geometry = require("@root/geometry")
local types = require("@root/types")

type Item = types.Item

-- The size the app draws an item at. A card takes the height the app last
-- measured for it, or an estimate from its text until the app has measured it.
-- Groups and images use their stored width and height.
local function getSize(item: Item): (number, number)
	if item.type == "task" then
		return geometry.TASK_WIDTH, item.height or estimateTaskHeight(item)
	end

	return item.width or geometry.GROUP_SIZE.width, item.height or geometry.GROUP_SIZE.height
end

return getSize
