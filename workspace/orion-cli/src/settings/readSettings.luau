local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")

-- The app's preferences for this data folder. A missing or unreadable file
-- reads as none.
return function(root: string): json.Object
	local file = tostring(path.join(root, fileNames.settings))

	if not fs.exists(file) then
		return json.object({})
	end

	local didRead, settings = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)

	return if didRead and settings then settings else json.object({})
end
