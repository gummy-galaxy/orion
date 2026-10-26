--[[
	Writes `workspace/orion-app/src/cardTypes/builtinTypes.json` from the card
	types the CLI ships, so the app draws built-in cards before the server
	sends its declarations, and its tests have them. Run it after changing
	`workspace/orion-cli/src/cardTypes/builtinTypes.luau`, and commit what it
	writes. With `--check`, it leaves the file as it was and exits nonzero when
	it's out of date.
]]
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local builtinTypes = require("@cli/cardTypes/builtinTypes")
local encodeStableJson = require("@cli/store/encodeStableJson")
local serializeCardType = require("@cli/cardTypes/serializeCardType")

local runScript = require("@cli/runScript")

local target = path.resolve("workspace/orion-app/src/cardTypes/builtinTypes.json")
local checkOnly = table.find(process.args, "--check") ~= nil

local function generate(): string
	local declared: json.Array = {}

	for _, cardType in builtinTypes do
		table.insert(declared, serializeCardType(cardType))
	end

	return encodeStableJson(declared) .. "\n"
end

runScript(function()
	local contents = generate()
	local current = if fs.exists(target) then fs.readFileToString(target) else nil

	if current == contents then
		print("workspace/orion-app/src/cardTypes/builtinTypes.json is up to date")
		return
	end

	if checkOnly then
		print(
			"workspace/orion-app/src/cardTypes/builtinTypes.json is out of date. Run `lute run card-types` and commit the result."
		)
		process.exit(1)
	end

	fs.writeStringToFile(target, contents)
	print("Updated workspace/orion-app/src/cardTypes/builtinTypes.json")
end)
