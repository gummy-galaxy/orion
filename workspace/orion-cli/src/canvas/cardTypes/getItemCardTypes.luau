local json = require("@std/json")

local cardTypes = require("@root/canvas/cardTypes/types")
local findCardType = require("@root/canvas/cardTypes/findCardType")
local getRefCardType = require("@root/canvas/cardTypes/getRefCardType")
local getRefs = require("@root/canvas/refs/getRefs")
local getStringField = require("@root/common/getStringField")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Item = types.Item
type ItemTypes = cardTypes.ItemTypes

local function supersedes(name: string, other: string): boolean
	local cardType = findCardType(name)
	return cardType ~= nil and table.find(cardType.supersedes or {}, other) ~= nil
end

-- The types attached to a card, each once. The primary type, which picks the
-- face, is the one a person chose for the card, or else its first source's,
-- or else a placeholder when it names a repository a pull request is expected
-- in. A source's type takes over when it supersedes it, as a pull request
-- does a placeholder, and a card with none is a step. After the primary come
-- the sources' types, in the order of the card's refs, then the ones people
-- attached. Groups aren't cards and carry none.
local function getItemCardTypes(item: Item): ItemTypes?
	if isGroup(item) then
		return nil
	elseif item.type == "image" then
		return { primary = "image", types = { "image" } }
	end

	local chosen = getStringField(item.data.type)
	local sourced: { string } = {}

	for _, ref in getRefs(item) do
		local name = getRefCardType(ref)

		if name then
			table.insert(sourced, name)
		end
	end

	local expected = if getStringField(item.data.repo) then "placeholder" else nil
	local primary = chosen or sourced[1] or expected or "step"

	for _, candidate in sourced do
		if supersedes(candidate, primary) then
			primary = candidate
		end
	end

	local attached: { string } = { primary }
	local seen: { [string]: boolean } = { [primary] = true }

	local function attach(name: string?)
		if name and not seen[name] then
			seen[name] = true
			table.insert(attached, name)
		end
	end

	attach(chosen)

	for _, candidate in sourced do
		attach(candidate)
	end

	for _, value in json.asArray(item.data.types) or {} do
		attach(getStringField(value))
	end

	return { primary = primary, types = attached }
end

return getItemCardTypes
