local chooseItemKind = require("@root/canvas/items/chooseItemKind")
local findRef = require("@root/canvas/refs/findRef")
local getStringField = require("@root/common/getStringField")
local isComponent = require("@root/canvas/items/isComponent")
local isGate = require("@root/canvas/items/isGate")
local isNote = require("@root/canvas/items/isNote")
local types = require("@root/types")

type Item = types.Item

-- Recomputes an item's kind from its repository, pull request, and gate status
-- after its refs change.
local function refreshItemKind(item: Item)
	if isNote(item) or isComponent(item) then
		return
	end

	local kind = if isGate(item) then "gate" else nil
	item.data.itemKind = chooseItemKind(getStringField(item.data.repo), if findRef(item, "pull") then 1 else nil, kind)
end

return refreshItemKind
