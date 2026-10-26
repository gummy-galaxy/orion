local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local writerState = require("@root/store/writerState")

-- Appends a revision and its writer to the canvas's revision log, beside its
-- backups, so orion history list can say who made each one.
local function recordRevision(dir: string, revision: number, time: string)
	local folder = path.join(dir, fileNames.backups)
	local writer = writerState.current
	local entry = json.object({ revision = revision, time = time, by = if writer then writer.by else "app" })
	entry.command = if writer then writer.command else nil
	ensureDirectory(folder)

	local handle = fs.open(path.join(folder, fileNames.revisions), "a")
	fs.write(handle, json.serialize(entry) .. "\n")
	fs.close(handle)
end

return recordRevision
