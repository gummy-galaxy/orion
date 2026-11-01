local json = require("@std/json")

local getCardTypeRegistry = require("@root/canvas/cardTypes/getCardTypeRegistry")
local serializeCardType = require("@root/canvas/cardTypes/serializeCardType")

-- Every registered type as JSON, in order, for orion card types --json and the
-- app.
local function serializeCardTypeRegistry(): json.Array
	local result: json.Array = {}

	for _, cardType in getCardTypeRegistry().ordered do
		table.insert(result, serializeCardType(cardType))
	end

	return result
end

return serializeCardTypeRegistry
