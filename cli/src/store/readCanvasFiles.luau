local fs = require("@std/fs")
local path = require("@std/path")
local task = require("@std/task")

local fileNames = require("@root/fileNames")
local getDocPath = require("@root/store/getDocPath")
local joinCanvasFiles = require("@root/store/joinCanvasFiles")
local storeTypes = require("@root/store/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot

-- Long enough to outlast a writer, since writers give up waiting for the lock after five seconds.
local ATTEMPTS = 200
local RETRY_SECONDS = 0.025

local function getStamp(file: string): string?
	local succeeded, metadata = pcall(fs.metadata, file)
	return if succeeded then `{metadata.size}:{metadata.modified:toNanoseconds()}` else nil
end

-- A marker without the lock is left by a writer that stopped partway, so there's no write to wait for.
local function isWriting(dir: string): boolean
	return fs.exists(path.join(dir, fileNames.pendingWrite)) and fs.exists(path.join(dir, fileNames.lock))
end

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

local function readFiles(dir: string): { [string]: string }
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

--[[
	Reads a canvas folder's files, or nil when it has none yet. A write replaces several files, `canvas.json` last,
	while its marker is down, so a read that saw the marker or a different `canvas.json` by the time it finished
	reads again rather than return a write half done.
]]
local function readCanvasFiles(dir: string): CanvasSnapshot?
	local canvasFile = getDocPath(dir)

	for attempt = 1, ATTEMPTS do
		local before = getStamp(canvasFile)

		if before == nil then
			assert(
				not fs.exists(path.join(dir, fileNames.legacyDocument)),
				`{dir} still keeps its canvas in {fileNames.legacyDocument}; run any orion command to move it to files`
			)
			return nil
		end

		local isLast = attempt == ATTEMPTS

		if isLast or not isWriting(dir) then
			local succeeded, files = pcall(readFiles, dir)

			if succeeded and (isLast or (not isWriting(dir) and getStamp(canvasFile) == before)) then
				return { files = files, document = joinCanvasFiles(files) }
			elseif not succeeded and isLast then
				error(files, 0)
			end
		end

		task.wait(RETRY_SECONDS)
	end

	return nil
end

return readCanvasFiles
