local fs = require("@std/fs")
local path = require("@std/path")
local task = require("@std/task")

local fileNames = require("@root/fileNames")
local getDocPath = require("@root/storage/canvases/getDocPath")
local hasSqlite = require("@root/storage/index/hasSqlite")
local joinCanvasFiles = require("@root/storage/files/joinCanvasFiles")
local readCanvasFolder = require("@root/storage/files/readCanvasFolder")
local readCanvasIndex = require("@root/storage/index/readCanvasIndex")
local recoverCanvasWrite = require("@root/storage/transactions/recoverCanvasWrite")
local resolveCanvasFiles = require("@root/storage/files/resolveCanvasFiles")
local runWithLock = require("@root/storage/transactions/runWithLock")
local storeTypes = require("@root/storage/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot

-- Long enough to outlast a writer, since writers give up waiting for the lock
-- after five seconds.
local ATTEMPTS = 200
local RETRY_SECONDS = 0.025

local function getStamp(file: string): string?
	local succeeded, metadata = pcall(fs.metadata, file)
	return if succeeded then `{metadata.size}:{metadata.modified:toNanoseconds()}` else nil
end

-- A marker without the lock is left by a writer that stopped partway, so
-- there's no write to wait for.
local function isWriting(dir: string): boolean
	return fs.exists(path.join(dir, fileNames.pendingWrite)) and fs.exists(path.join(dir, fileNames.lock))
end

local function read(dir: string, includeFiles: boolean): CanvasSnapshot
	if hasSqlite() then
		return assert(readCanvasIndex(dir, includeFiles), `{dir} has no {fileNames.document}`)
	end

	local files = readCanvasFolder(dir)
	local resolved, problems = resolveCanvasFiles(files)
	local document, entries = joinCanvasFiles(resolved)
	return { files = files, document = document, entries = entries, problems = problems }
end

--[[
	Reads a canvas folder through its index, or nil when it has no files yet.
	The index catches up with the files first, so a read always sees what's on
	disk. A write replaces several files, `local.json` last, while its marker is
	down, so a read that saw the marker or a different `local.json` by the time
	it finished reads again rather than return a write half done. A marker left
	by a writer that stopped partway is cleared by finishing its write first.
	Callers that hold the lock recover before reading, since this would wait on
	their own lock. With `includeFiles`, the snapshot also maps each file's path
	to its text, and keeps what each node and link file stored beside its entry.
]]
local function readCanvasFiles(dir: string, includeFiles: boolean?): CanvasSnapshot?
	local canvasFile = getDocPath(dir)
	local lastFile = tostring(path.join(dir, fileNames.localState))

	-- Waits out a live writer, or finishes a write whose process is gone. A
	-- lock that can't be had yet, such as one a killed writer left that isn't
	-- stale enough to take, leaves the read to retry as before.
	if fs.exists(path.join(dir, fileNames.pendingWrite)) then
		pcall(runWithLock, dir, function(): nil
			recoverCanvasWrite(dir)
			return nil
		end)
	end

	for attempt = 1, ATTEMPTS do
		if not fs.exists(canvasFile) then
			assert(
				not fs.exists(path.join(dir, fileNames.legacyDocument)),
				`{dir} still keeps its canvas in {fileNames.legacyDocument}; run any orion command to move it to files`
			)
			return nil
		end

		local before = getStamp(lastFile)
		local isLast = attempt == ATTEMPTS

		if isLast or not isWriting(dir) then
			local succeeded, snapshot = pcall(read, dir, includeFiles == true)

			-- A read that failed with no write in its way, such as on a file
			-- that doesn't parse, fails the same way the next time.
			if isLast or (not isWriting(dir) and getStamp(lastFile) == before) then
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
