local findCardType = require("@root/cardTypes/findCardType")
local getItemTypes = require("@root/cardTypes/getItemTypes")
local types = require("@root/types")

type Item = types.Item

-- A component is a part of a system drawn on the canvas, like a service or a
-- data store, rather than work: a card whose primary type draws it that way.
local function isComponent(item: Item): boolean
	local itemTypes = item.type == "task" and getItemTypes(item)
	local cardType = if itemTypes then findCardType(itemTypes.primary) else nil
	return cardType ~= nil and cardType.face.layout == "component"
end

return isComponent
