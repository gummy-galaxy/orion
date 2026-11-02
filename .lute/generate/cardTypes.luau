--[[
	Writes `workspace/orion-app/src/cardTypes/builtinTypes.json` from the card
	types the CLI ships, so the app draws built-in cards before the server sends
	its declarations, and its tests have them. Run it after changing
	`workspace/orion-cli/src/canvas/cardTypes/builtinCardTypes.luau`, and
	commit what it writes.
]]
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local builtinCardTypes = require("@cli/canvas/cardTypes/builtinCardTypes")
local encodeStableJson = require("@cli/storage/files/encodeStableJson")
local serializeCardType = require("@cli/canvas/cardTypes/serializeCardType")

local target = path.resolve("workspace/orion-app/src/cardTypes/builtinTypes.json")

local function generate(): string
	local declared: json.Array = {}

	for _, cardType in builtinCardTypes do
		table.insert(declared, serializeCardType(cardType))
	end

	return encodeStableJson(declared) .. "\n"
end

-- Writes the file, or with `checkOnly` leaves it alone. Returns false when
-- `checkOnly` finds it out of date.
local function generateCardTypes(checkOnly: boolean): boolean
	local contents = generate()
	local current = if fs.exists(target) then fs.readFileToString(target) else nil

	if current == contents then
		print("workspace/orion-app/src/cardTypes/builtinTypes.json is up to date")
		return true
	end

	if checkOnly then
		print(
			"workspace/orion-app/src/cardTypes/builtinTypes.json is out of date. "
				.. "Run `lute run generate cardTypes` and commit the result."
		)
		return false
	end

	fs.writeStringToFile(target, contents)
	print("Updated workspace/orion-app/src/cardTypes/builtinTypes.json")

	return true
end

return generateCardTypes
