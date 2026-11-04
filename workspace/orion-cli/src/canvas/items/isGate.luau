local getStringField = require("@root/common/getStringField")
local types = require("@root/types")

type Item = types.Item

local function isGate(item: Item): boolean
	return item.type == "task" and getStringField(item.data.type) == "gate"
end

return isGate
