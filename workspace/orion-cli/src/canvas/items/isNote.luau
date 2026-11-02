local findCardType = require("@root/canvas/cardTypes/findCardType")
local getItemCardTypes = require("@root/canvas/cardTypes/getItemCardTypes")
local types = require("@root/types")

type Item = types.Item

-- A card drawn as a note, from its primary type's face.
local function isNote(item: Item): boolean
	local itemTypes = item.type == "task" and getItemCardTypes(item)
	local cardType = if itemTypes then findCardType(itemTypes.primary) else nil
	return cardType ~= nil and cardType.face.layout == "note"
end

return isNote
