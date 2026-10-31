local json = require("@std/json")

local getRegistry = require("@root/cardTypes/getRegistry")
local serializeCardType = require("@root/cardTypes/serializeCardType")

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
