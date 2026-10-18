local getStringField = require("@root/getStringField")
local types = require("@root/types")

type Item = types.Item

local function isNote(item: Item): boolean
	return item.type == "task" and getStringField(item.data.itemKind) == "note"
end

return isNote
