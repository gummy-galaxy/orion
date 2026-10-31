local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local getDocPath = require("@root/storage/canvases/getDocPath")

local function readFolder(dir: string, folder: string, files: { [string]: string })
	local full = path.join(dir, folder)

	if not fs.exists(full) then
		return
	end

	for _, entry in fs.listDirectory(full) do
		if entry.type == "file" and entry.name:match("%.json$") then
			files[`{folder}/{entry.name}`] = fs.readFileToString(path.join(full, entry.name))
		end
	end
end

-- Reads every file of a canvas folder, keyed by path as `splitDocObject` writes
-- them, without the index.
local function readCanvasFolder(dir: string): { [string]: string }
	local files: { [string]: string } = {}
	files[fileNames.document] = fs.readFileToString(getDocPath(dir))
	readFolder(dir, fileNames.nodes, files)
	readFolder(dir, fileNames.links, files)

	local localState = path.join(dir, fileNames.localState)

	if fs.exists(localState) then
		files[fileNames.localState] = fs.readFileToString(localState)
	end

	return files
end

return readCanvasFolder
