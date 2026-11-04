local getStringField = require("@root/common/getStringField")
local types = require("@root/types")

type Item = types.Item

local function isNote(item: Item): boolean
	return item.type == "task" and getStringField(item.data.type) == "note"
end

return isNote
