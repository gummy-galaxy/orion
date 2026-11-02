local json = require("@std/json")

local getRefCardType = require("@root/canvas/cardTypes/getRefCardType")
local getStringField = require("@root/common/getStringField")
local types = require("@root/types")

type Item = types.Item

-- Pull request, placeholder, and step are the kinds a card's refs and
-- repository decide, so a card doesn't store them.
local function isKindFromRefs(kind: string?): boolean
	return kind == "pr" or kind == "placeholder" or kind == "step"
end

--[[
	Cards used to store a fixed kind in `data.itemKind`. Now a card's kind comes
	from its types. A type a person chose, such as gate, note, or component, is
	stored as `data.type`. Otherwise the card's refs and repository decide: a
	pull request ref makes a pull request card, a GitHub issue or a repository
	with no pull request yet makes a placeholder, and anything else is a step.

	This converts a card read in an older shape. It records on each ref the type
	that ref attaches, where it has one, and moves a chosen kind from `itemKind`
	to `data.type`. It also drops a stored `data.type` of pr, placeholder, or
	step. #748 stored those for every card, and keeping one would fix the card's
	kind even after its refs change.
]]
local function migrateItemKind(item: Item)
	for _, value in json.asArray(item.data.refs) or {} do
		local ref = json.asObject(value)

		if ref and ref.type == nil and type(ref.kind) == "string" and type(ref.key) == "string" then
			ref.type = getRefCardType(ref :: any)
		end
	end

	if isKindFromRefs(getStringField(item.data.type)) then
		item.data.type = nil
	end

	local kind = getStringField(item.data.itemKind)
	item.data.itemKind = nil

	if kind and not isKindFromRefs(kind) and item.data.type == nil then
		item.data.type = kind
	end
end

return migrateItemKind
