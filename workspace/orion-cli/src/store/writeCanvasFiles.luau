local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local applyCanvasWrite = require("@root/store/applyCanvasWrite")
local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local finishCanvasWrite = require("@root/store/finishCanvasWrite")
local getBackupName = require("@root/store/getBackupName")
local joinCanvasFiles = require("@root/store/joinCanvasFiles")
local journalCanvasWrite = require("@root/store/journalCanvasWrite")
local pruneBackups = require("@root/store/pruneBackups")
local splitDocObject = require("@root/store/splitDocObject")
local storeTypes = require("@root/store/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot
type CanvasWrite = storeTypes.CanvasWrite

-- Saves the whole canvas a write replaces as one file in the backups folder.
-- Backups are best-effort: a failed backup never blocks the write itself.
local function backUp(dir: string, previous: CanvasSnapshot)
	pcall(function()
		local now = os.time()
		local folder = path.join(dir, fileNames.backups)
		local revision = if type(previous.document.revision) == "number" then previous.document.revision else 0
		local backup = path.join(folder, getBackupName(revision, now))
		ensureDirectory(folder)

		-- The snapshot's document may have been decoded and changed since, so
		-- the files are joined again.
		if not fs.exists(backup) then
			local document = if previous.files then joinCanvasFiles(previous.files) else previous.document
			fs.writeStringToFile(backup, json.serialize(document, true))
		end

		pruneBackups(dir, now)
	end)
end

local function getRemovals(dir: string, files: { [string]: string }): { string }
	local removes: { string } = {}

	for _, folder in { fileNames.nodes, fileNames.links } do
		for _, entry in fs.listDirectory(path.join(dir, folder)) do
			local file = `{folder}/{entry.name}`

			if entry.type == "file" and entry.name:match("%.json$") and not files[file] then
				table.insert(removes, file)
			end
		end
	end

	return removes
end

--[[
	Writes a whole canvas, in the shape `encodeDocObject` returns, as the files
	of its folder. Only files whose text differs from `previous` are rewritten,
	node and link files the canvas no longer has are removed, and `local.json`,
	which holds the revision, goes last. A marker stays down for the length of
	the write so readers wait it out, and the index journals the write before
	any file moves, so `recoverCanvasWrite` can finish one that stops partway.
	Callers hold the lock, and pass what they read under it as `previous`, with
	its files, whose canvas is backed up first. Fields that changed since
	`previous` are stamped with the current time.
]]
local function writeCanvasFiles(dir: string, document: json.Object, previous: CanvasSnapshot?)
	local files = splitDocObject(document, previous, os.date("!%Y-%m-%dT%H:%M:%SZ") :: string)
	-- Replaced on every write, even unchanged, so a reader that started before
	-- it can tell the files moved under it.
	files[fileNames.localState] = files[fileNames.localState] or "{}\n"
	local previousFiles = if previous and previous.files then previous.files else {}
	local marker = path.join(dir, fileNames.pendingWrite)
	local writes: { [string]: string } = {}

	if previous then
		backUp(dir, previous)
	end

	for file, contents in files do
		if file == fileNames.localState or previousFiles[file] ~= contents then
			writes[file] = contents
		end
	end

	ensureDirectory(path.join(dir, fileNames.nodes))
	ensureDirectory(path.join(dir, fileNames.links))

	local write: CanvasWrite = { writes = writes, removes = getRemovals(dir, files) }
	local revision = if type(document.revision) == "number" then document.revision else nil

	-- The marker goes down before the journal, so an unfinished operation
	-- always has a marker to be found by.
	fs.writeStringToFile(marker, `{process.pid()}`)

	local id = journalCanvasWrite(dir, write, revision)
	local stamps = applyCanvasWrite(dir, write)

	if id then
		finishCanvasWrite(dir, id, stamps)
	end

	fs.remove(marker)
end

return writeCanvasFiles
