local fs = require("@std/fs")
local path = require("@std/path")

local isValidWorkspace = require("@root/storage/canvases/isValidWorkspace")

local CANVAS_FOLDER = "canvases"

-- The names of every canvas a data folder holds a folder for, `default`
-- first, whether or not `canvases.json` lists them.
local function getCanvasNames(root: string): { string }
	local names = { "default" }
	local folder = path.join(root, CANVAS_FOLDER)

	if fs.exists(folder) and fs.type(folder) == "dir" then
		for _, entry in fs.listDirectory(folder) do
			if entry.type == "dir" and entry.name ~= "default" and isValidWorkspace(entry.name) then
				table.insert(names, entry.name)
			end
		end
	end

	return names
end

return getCanvasNames
