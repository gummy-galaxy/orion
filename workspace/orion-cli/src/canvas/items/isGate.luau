local getMeaning = require("@root/canvas/cardTypes/getMeaning")
local types = require("@root/types")

type Item = types.Item

-- Work that's done once everything it waits on is, like a milestone or a
-- sign-off, as its type declares.
local function isGate(item: Item): boolean
	local meaning = item.type == "task" and getMeaning(item)
	return if meaning then meaning.isWork and meaning.doneWhen == "inputs" else false
end

return isGate
