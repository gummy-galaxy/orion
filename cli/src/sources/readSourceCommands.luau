local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")

--[[
	The commands this machine runs for a canvas's sources, by source id. They live in the data folder's
	`commands.json`, keyed by canvas name, rather than in the canvas's own files, so a canvas shared through git
	can't carry a program for someone else's Orion to run. A missing or unreadable file reads as none.
]]
local function readSourceCommands(root: string, canvas: string): { [string]: { string } }
	local file = tostring(path.join(root, fileNames.commands))
	local commands: { [string]: { string } } = {}

	if not fs.exists(file) then
		return commands
	end

	local succeeded, decoded = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)
	local byCanvas = if succeeded and decoded then json.asObject(decoded[canvas]) else nil

	for id, value in byCanvas or {} do
		local argv = json.asArray(value)

		if type(id) ~= "string" or not argv or #argv == 0 then
			continue
		end

		local parts: { string } = {}

		for _, part in argv do
			if type(part) == "string" then
				table.insert(parts, part)
			end
		end

		if #parts == #argv then
			commands[id] = parts
		end
	end

	return commands
end

return readSourceCommands
