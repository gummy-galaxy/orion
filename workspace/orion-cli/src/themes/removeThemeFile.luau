local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")

-- Deletes a theme file from the themes folder by the name `theme list` shows.
-- Returns the name that was removed.
local function removeThemeFile(root: string, name: string): string
	assert(name:sub(-5) == ".json", "a theme file name ends in .json")
	assert(path.basename(name) == name, "name a theme file, not a path")

	local target = path.join(root, fileNames.themes, name)

	assert(fs.exists(target) and fs.type(target) == "file", `no theme file named {name}`)

	fs.remove(target)

	return name
end

return removeThemeFile
