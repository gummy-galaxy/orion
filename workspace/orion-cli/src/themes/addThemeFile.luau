local fs = require("@std/fs")
local path = require("@std/path")

local checkThemeFile = require("@root/themes/checkThemeFile")
local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local themeLimits = require("@root/themes/themeLimits")

export type AddedTheme = {
	file: string,
	label: string,
	replaced: boolean,
	warnings: { string },
}

-- Checks a theme file and copies it into the themes folder under its own name.
-- The app lists it on its next read. A file that cannot be used is refused and
-- nothing is copied. A file with the same name is replaced.
local function addThemeFile(root: string, source: string): AddedTheme
	assert(source:sub(-5) == ".json", "a theme file must be a .json file")
	assert(fs.exists(source) and fs.type(source) == "file", `{source} is not a file`)
	assert(fs.metadata(source).size <= themeLimits.maxBytes, "a theme file must be 256 KiB or smaller")

	local name = assert(path.basename(source), `{source} has no file name`)
	local text = fs.readFileToString(source)
	local check = checkThemeFile(name, text)

	assert(check.error == nil, `{name} {check.error}`)

	local folder = path.join(root, fileNames.themes)
	ensureDirectory(folder)

	local target = path.join(folder, name)
	local replaced = fs.exists(target)

	fs.writeStringToFile(target, text)

	return { file = name, label = check.label, replaced = replaced, warnings = check.notes }
end

return addThemeFile
