local getStringField = require("@root/common/getStringField")
local types = require("@root/types")

type Item = types.Item

local function getLabel(item: Item): string
	return getStringField(item.data.label) or ""
end

return getLabel
