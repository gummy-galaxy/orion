local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local decodeDoc = require("@root/store/decodeDoc")
local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local getBackupName = require("@root/store/getBackupName")
local getDocPath = require("@root/store/getDocPath")
local pruneBackups = require("@root/store/pruneBackups")

local writeSequence = 0

-- Replaces the data file with `contents` in one move, backing up the file it replaces first. Callers hold the lock.
local function writeDocFile(dir: string, contents: string)
	local file = getDocPath(dir)
	writeSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{writeSequence}`
	fs.writeStringToFile(temporary, contents)

	-- Backups are best-effort: a failed backup never blocks the write itself.
	pcall(function()
		if fs.exists(file) then
			local now = os.time()
			local folder = path.join(dir, fileNames.backups)
			ensureDirectory(folder)

			local previous = decodeDoc(fs.readFileToString(file))
			local backup = path.join(folder, getBackupName(previous.revision, now))

			if not fs.exists(backup) then
				fs.copy(file, backup)
			end

			pruneBackups(dir, now)
		end
	end)

	local succeeded, failureMessage = pcall(fs.move, temporary, file)

	if not succeeded then
		pcall(fs.remove, temporary)
		error(failureMessage, 0)
	end
end

return writeDocFile
