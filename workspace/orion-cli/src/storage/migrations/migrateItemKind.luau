local json = require("@std/json")

local getRefCardType = require("@root/canvas/cardTypes/getRefCardType")
local getStringField = require("@root/common/getStringField")
local types = require("@root/types")

type Item = types.Item

--[[
	Moves a card's `data.itemKind` onto types. Each ref records the type it
	attaches, and a kind a person chose, such as gate, note, or component,
	becomes the card's `data.type`. Pull request, placeholder, and step kinds
	follow from the card's refs and repository, so they store nothing. The next
	write saves the canvas it replaces as a backup, as every write does.
]]
local function migrateItemKind(item: Item)
	for _, value in json.asArray(item.data.refs) or {} do
		local ref = json.asObject(value)

		if ref and ref.type == nil and type(ref.kind) == "string" and type(ref.key) == "string" then
			ref.type = getRefCardType(ref :: any)
		end
	end

	local kind = getStringField(item.data.itemKind)
	item.data.itemKind = nil

	if kind and kind ~= "pr" and kind ~= "placeholder" and kind ~= "step" and item.data.type == nil then
		item.data.type = kind
	end
end

return migrateItemKind
