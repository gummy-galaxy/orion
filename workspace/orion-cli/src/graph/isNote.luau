local findCardType = require("@root/cardTypes/findCardType")
local getItemTypes = require("@root/cardTypes/getItemTypes")
local types = require("@root/types")

type Item = types.Item

-- A card drawn as a note, from its primary type's face.
local function isNote(item: Item): boolean
	local itemTypes = item.type == "task" and getItemTypes(item)
	local cardType = if itemTypes then findCardType(itemTypes.primary) else nil
	return cardType ~= nil and cardType.face.layout == "note"
end

return isNote
