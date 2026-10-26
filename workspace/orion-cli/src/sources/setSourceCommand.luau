local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local encodeStableJson = require("@root/store/encodeStableJson")
local fileNames = require("@root/fileNames")
local replaceFile = require("@root/store/replaceFile")
local runWithLock = require("@root/store/runWithLock")

local function readFile(file: string): json.Object
	if not fs.exists(file) then
		return json.object({})
	end

	local succeeded, decoded = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)

	return if succeeded and decoded then decoded else json.object({})
end

-- json.object keeps a marker under a key that isn't a string, so emptiness
-- counts only string keys.
local function isEmpty(object: json.Object): boolean
	for key in object do
		if type(key) == "string" then
			return false
		end
	end

	return true
end

--[[
	Records the command this machine runs for one of a canvas's sources in the
	data folder's `commands.json`, or removes it when `command` is nil. Writes
	hold the data folder's lock, so two canvases changing their sources at once
	both keep their commands.
]]
local function setSourceCommand(root: string, canvas: string, id: string, command: { string }?)
	runWithLock(root, function(): nil
		local all = readFile(tostring(path.join(root, fileNames.commands)))
		local byCanvas = json.asObject(all[canvas]) or json.object({})

		if command then
			local argv: json.Array = {}

			for _, part in command do
				table.insert(argv, part)
			end

			byCanvas[id] = argv
		else
			byCanvas[id] = nil
		end

		all[canvas] = if isEmpty(byCanvas) then nil else byCanvas
		replaceFile(root, fileNames.commands, encodeStableJson(all))
		return nil
	end)
end

return setSourceCommand
