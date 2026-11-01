local getCardTypeMeaning = require("@root/canvas/cardTypes/getCardTypeMeaning")
local types = require("@root/types")

type Item = types.Item

-- Cards that count as work, as their type declares. Notes and components pass
-- blocking through and never do.
local function isWork(item: Item): boolean
	local meaning = item.type == "task" and getCardTypeMeaning(item)
	return if meaning then meaning.isWork else false
end

return isWork
