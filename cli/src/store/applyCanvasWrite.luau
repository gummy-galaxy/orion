local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local replaceFile = require("@root/store/replaceFile")
local storeTypes = require("@root/store/types")

type CanvasWrite = storeTypes.CanvasWrite

local function getFullPath(dir: string, file: string): string
	return tostring(path.join(dir, table.unpack(file:split("/"))))
end

--[[
	Puts a write's files in place: every file but `canvas.json` in path order, then the removals, then `canvas.json`
	last, so its change marks a finished write. Writing a file again with the same text is harmless, so a write that
	stopped partway can be applied again from the start. Returns each written file's time in whole seconds, which
	the index records.
]]
local function applyCanvasWrite(dir: string, write: CanvasWrite): { [string]: number }
	local files: { string } = {}

	for file in write.writes do
		if file ~= fileNames.document then
			table.insert(files, file)
		end
	end

	table.sort(files)

	for _, file in files do
		replaceFile(dir, file, write.writes[file])
	end

	for _, file in write.removes do
		local full = getFullPath(dir, file)

		if fs.exists(full) then
			fs.remove(full)
		end
	end

	if write.writes[fileNames.document] then
		replaceFile(dir, fileNames.document, write.writes[fileNames.document])
		table.insert(files, fileNames.document)
	end

	local stamps: { [string]: number } = {}

	for _, file in files do
		local succeeded, metadata = pcall(fs.metadata, getFullPath(dir, file))

		if succeeded then
			stamps[file] = math.floor(metadata.modified:toSeconds())
		end
	end

	return stamps
end

return applyCanvasWrite
