local isComponent = require("@root/graph/isComponent")
local isNote = require("@root/graph/isNote")
local types = require("@root/types")

type Item = types.Item

-- Cards that count as work. Notes and components pass blocking through and never do.
local function isWork(item: Item): boolean
	return item.type == "task" and not isNote(item) and not isComponent(item)
end

return isWork
