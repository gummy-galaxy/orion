local cardTypes = require("@root/canvas/cardTypes/types")
local findCardType = require("@root/canvas/cardTypes/findCardType")
local getItemTypes = require("@root/canvas/cardTypes/getItemTypes")
local getStringField = require("@root/common/getStringField")
local types = require("@root/types")

type Item = types.Item
type StateMeaning = cardTypes.StateMeaning

local MEANINGS: { [string]: boolean } =
	{ todo = true, active = true, review = true, blocked = true, deferred = true, done = true }

-- What a card's recorded state counts as, from its primary type's states, such
-- as done for a design marked Approved. A type with no states, like a note,
-- reads a recorded meaning as itself. A card that records no state, or one its
-- type doesn't declare, is still to do.
local function getStateMeaning(item: Item): StateMeaning
	local recorded = getStringField(item.data.status)
	local itemTypes = getItemTypes(item)
	local cardType = if itemTypes then findCardType(itemTypes.primary) else nil

	local states = if cardType then cardType.states else {}

	for _, state in states do
		if state.name == recorded then
			return state.means
		end
	end

	if #states == 0 and recorded and MEANINGS[recorded] then
		return recorded :: StateMeaning
	end

	return "todo"
end

return getStateMeaning
