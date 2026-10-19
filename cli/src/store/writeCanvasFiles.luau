local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local getBackupName = require("@root/store/getBackupName")
local joinCanvasFiles = require("@root/store/joinCanvasFiles")
local pruneBackups = require("@root/store/pruneBackups")
local splitDocObject = require("@root/store/splitDocObject")
local storeTypes = require("@root/store/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot

local writeSequence = 0

local function getFullPath(dir: string, file: string): string
	return tostring(path.join(dir, table.unpack(file:split("/"))))
end

-- Replaces one file in a single move, so a reader sees either the old text or the new.
local function replaceFile(dir: string, file: string, contents: string)
	local full = getFullPath(dir, file)
	writeSequence += 1
	local temporary = `{full}.tmp.{process.pid()}.{writeSequence}`
	fs.writeStringToFile(temporary, contents)

	local succeeded, failureMessage = pcall(fs.move, temporary, full)

	if not succeeded then
		pcall(fs.remove, temporary)
		error(failureMessage, 0)
	end
end

-- Saves the whole canvas a write replaces as one file in the backups folder. Backups are best-effort: a failed
-- backup never blocks the write itself.
local function backUp(dir: string, previous: CanvasSnapshot)
	pcall(function()
		local now = os.time()
		local folder = path.join(dir, fileNames.backups)
		local document = joinCanvasFiles(previous.files)
		local revision = if type(document.revision) == "number" then document.revision else 0
		local backup = path.join(folder, getBackupName(revision, now))
		ensureDirectory(folder)

		if not fs.exists(backup) then
			fs.writeStringToFile(backup, json.serialize(document, true))
		end

		pruneBackups(dir, now)
	end)
end

--[[
	Writes a whole canvas, in the shape `encodeDocObject` returns, as the files of its folder. Only files whose
	text differs from `previous` are rewritten, node and link files the canvas no longer has are removed, and
	`local.json`, which holds the revision, goes last. A marker stays down for the length of the write so readers
	wait it out. Callers hold the lock, and pass what they read under it as `previous`, whose canvas is backed up
	first. Fields that changed since `previous` are stamped with the current time.
]]
local function writeCanvasFiles(dir: string, document: json.Object, previous: CanvasSnapshot?)
	local files = splitDocObject(document, previous, os.date("!%Y-%m-%dT%H:%M:%SZ") :: string)
	local previousFiles = if previous then previous.files else {}
	local marker = path.join(dir, fileNames.pendingWrite)

	if previous then
		backUp(dir, previous)
	end

	ensureDirectory(path.join(dir, fileNames.nodes))
	ensureDirectory(path.join(dir, fileNames.links))
	fs.writeStringToFile(marker, `{process.pid()}`)

	for file, contents in files do
		if file ~= fileNames.document and file ~= fileNames.localState and previousFiles[file] ~= contents then
			replaceFile(dir, file, contents)
		end
	end

	for _, folder in { fileNames.nodes, fileNames.links } do
		for _, entry in fs.listDirectory(path.join(dir, folder)) do
			if entry.type == "file" and entry.name:match("%.json$") and not files[`{folder}/{entry.name}`] then
				fs.remove(path.join(dir, folder, entry.name))
			end
		end
	end

	if previousFiles[fileNames.document] ~= files[fileNames.document] then
		replaceFile(dir, fileNames.document, files[fileNames.document])
	end

	-- Replaced on every write, even unchanged, so a reader that started before it can tell the files moved under it.
	replaceFile(dir, fileNames.localState, files[fileNames.localState] or "{}\n")
	fs.remove(marker)
end

return writeCanvasFiles
