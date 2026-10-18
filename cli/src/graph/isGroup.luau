local types = require("@root/types")

type Item = types.Item

local function isGroup(item: Item): boolean
	return item.type == "cluster"
end

return isGroup
