local getMeaning = require("@root/canvas/cardTypes/getMeaning")
local types = require("@root/types")

type Item = types.Item

-- Cards that count as work, as their type declares. Notes and components pass
-- blocking through and never do.
local function isWork(item: Item): boolean
	local meaning = item.type == "task" and getMeaning(item)
	return if meaning then meaning.isWork else false
end

return isWork
