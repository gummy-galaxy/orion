local getStringField = require("@root/common/getStringField")
local types = require("@root/types")

type Item = types.Item

--[[
	Moves a card's kind from `data.itemKind` to `data.type`, the name every card
	stores it under now. A card that already has a `type` keeps it, and
	`itemKind` is removed either way, so the next write saves only `type`.
]]
local function migrateItemKind(item: Item)
	local kind = getStringField(item.data.itemKind)
	item.data.itemKind = nil

	if kind and item.data.type == nil then
		item.data.type = kind
	end
end

return migrateItemKind
