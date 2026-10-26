local getStringField = require("@root/getStringField")
local types = require("@root/types")

type Item = types.Item

-- A component is a part of a system drawn on the canvas, like a service or a
-- data store, rather than work.
local function isComponent(item: Item): boolean
	return item.type == "task" and getStringField(item.data.itemKind) == "component"
end

return isComponent
