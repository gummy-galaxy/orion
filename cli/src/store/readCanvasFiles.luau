local archivist = require("@archivist")
local fs = require("@std/fs")
local path = require("@std/path")
local task = require("@std/task")

local fileNames = require("@root/fileNames")
local getDocPath = require("@root/store/getDocPath")
local joinCanvasFiles = require("@root/store/joinCanvasFiles")
local readCanvasFolder = require("@root/store/readCanvasFolder")
local readCanvasIndex = require("@root/store/readCanvasIndex")
local storeTypes = require("@root/store/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot

local logger = archivist.getLogger("orion.index")

-- Long enough to outlast a writer, since writers give up waiting for the lock after five seconds.
local ATTEMPTS = 200
local RETRY_SECONDS = 0.025

-- Whether `sqlite3` can be run here. Without it, every read opens every file.
local hasSqlite = true

local function getStamp(file: string): string?
	local succeeded, metadata = pcall(fs.metadata, file)
	return if succeeded then `{metadata.size}:{metadata.modified:toNanoseconds()}` else nil
end

-- A marker without the lock is left by a writer that stopped partway, so there's no write to wait for.
local function isWriting(dir: string): boolean
	return fs.exists(path.join(dir, fileNames.pendingWrite)) and fs.exists(path.join(dir, fileNames.lock))
end

local function readFromFolder(dir: string): CanvasSnapshot
	local files = readCanvasFolder(dir)
	return { files = files, document = joinCanvasFiles(files) }
end

local function read(dir: string, includeFiles: boolean): CanvasSnapshot
	if hasSqlite then
		local succeeded, snapshot = pcall(readCanvasIndex, dir, includeFiles)

		if succeeded then
			return assert(snapshot, `{dir} has no {fileNames.document}`)
		elseif type(snapshot) == "string" and snapshot:find("Failed to spawn process", 1, true) then
			hasSqlite = false
			logger.warn("sqlite3 isn't installed, so canvases are read from every file:", snapshot)
		else
			error(snapshot, 0)
		end
	end

	return readFromFolder(dir)
end

--[[
	Reads a canvas folder through its index, or nil when it has no files yet. The index catches up with the files
	first, so a read always sees what's on disk. A write replaces several files, `canvas.json` last, while its
	marker is down, so a read that saw the marker or a different `canvas.json` by the time it finished reads again
	rather than return a write half done. With `includeFiles`, the snapshot also maps each file's path to its text.
]]
local function readCanvasFiles(dir: string, includeFiles: boolean?): CanvasSnapshot?
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
			local succeeded, snapshot = pcall(read, dir, includeFiles == true)

			-- A read that failed with no write in its way, such as on a file that doesn't parse, fails the same way
			-- the next time.
			if isLast or (not isWriting(dir) and getStamp(canvasFile) == before) then
				if not succeeded then
					error(snapshot, 0)
				end

				return snapshot
			end
		end

		task.wait(RETRY_SECONDS)
	end

	return nil
end

return readCanvasFiles
