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
		local revision = if type(previous.document.revision) == "number" then previous.document.revision else 0
		local backup = path.join(folder, getBackupName(revision, now))
		ensureDirectory(folder)

		-- The snapshot's document may have been decoded and changed since, so the files are joined again.
		if not fs.exists(backup) then
			local document = if previous.files then joinCanvasFiles(previous.files) else previous.document
			fs.writeStringToFile(backup, json.serialize(document, true))
		end

		pruneBackups(dir, now)
	end)
end

--[[
	Writes a whole canvas, in the shape `encodeDocObject` returns, as the files of its folder. Only files whose
	text differs from `previous` are rewritten, node and link files the canvas no longer has are removed, and
	`canvas.json` goes last. A marker stays down for the length of the write so readers wait it out. Callers hold
	the lock, and pass what they read under it as `previous`, with its files, whose canvas is backed up first.
]]
local function writeCanvasFiles(dir: string, document: json.Object, previous: CanvasSnapshot?)
	local files = splitDocObject(document)
	local previousFiles = if previous and previous.files then previous.files else {}
	local marker = path.join(dir, fileNames.pendingWrite)

	if previous then
		backUp(dir, previous)
	end

	ensureDirectory(path.join(dir, fileNames.nodes))
	ensureDirectory(path.join(dir, fileNames.links))
	fs.writeStringToFile(marker, `{process.pid()}`)

	for file, contents in files do
		if file ~= fileNames.document and previousFiles[file] ~= contents then
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

	local localState = path.join(dir, fileNames.localState)

	if not files[fileNames.localState] and fs.exists(localState) then
		fs.remove(localState)
	end

	replaceFile(dir, fileNames.document, files[fileNames.document])
	fs.remove(marker)
end

return writeCanvasFiles
