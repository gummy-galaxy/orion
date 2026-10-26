local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local themeLimits = require("@root/themes/themeLimits")

export type ThemeFile = { file: string, text: string?, error: string? }

-- Reads each .json file in the data folder's themes folder, sorted by name. A
-- missing folder reads as none. The contents are returned as text, since the
-- app checks what each file says.
return function(root: string): { ThemeFile }
	local folder = path.join(root, fileNames.themes)
	local files: { ThemeFile } = {}

	if not fs.exists(folder) or fs.type(folder) ~= "dir" then
		return files
	end

	local names: { string } = {}
	for _, entry in fs.listDirectory(folder) do
		if entry.type == "file" and entry.name:sub(-5) == ".json" then
			table.insert(names, entry.name)
		end
	end
	table.sort(names)

	for _, name in names do
		local file = tostring(path.join(folder, name))
		local didRead, result = pcall(function(): string
			assert(fs.metadata(file).size <= themeLimits.maxBytes, "larger than 256 KiB")
			return fs.readFileToString(file)
		end)

		if didRead then
			table.insert(files, { file = name, text = result :: string })
		else
			table.insert(files, { file = name, error = `could not be read: {tostring(result)}` })
		end
	end

	return files
end
