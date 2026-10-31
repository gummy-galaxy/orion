local json = require("@std/json")

local getRegistry = require("@root/canvas/cardTypes/getRegistry")
local serializeCardType = require("@root/canvas/cardTypes/serializeCardType")

-- Every registered type as JSON, in order, for orion type list --json and the
-- app.
local function serializeRegistry(): json.Array
	local result: json.Array = {}

	for _, cardType in getRegistry().ordered do
		table.insert(result, serializeCardType(cardType))
	end

	return result
end

return serializeRegistry
