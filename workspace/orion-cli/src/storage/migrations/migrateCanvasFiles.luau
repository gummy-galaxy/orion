local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")

local checkDataVersion = require("@root/storage/transactions/checkDataVersion")
local fileNames = require("@root/fileNames")
local getDocPath = require("@root/storage/canvases/getDocPath")
local isProcessAlive = require("@root/common/process/isProcessAlive")
local isValidWorkspace = require("@root/storage/canvases/isValidWorkspace")
local runWithLock = require("@root/storage/transactions/runWithLock")
local writeCanvasFiles = require("@root/storage/files/writeCanvasFiles")

local CANVAS_FOLDER = "canvases"

export type Options = {
	-- Returns the pid of an older `orion server start` still serving the data
	-- folder from `orion.json` files.
	findLegacyServer: ((root: string) -> number?)?,
}

-- A server that reads canvas folders says so in its record. Any other live
-- server that answers is older.
local function findLegacyServer(root: string): number?
	local file = path.join(root, fileNames.runtime)

	if not fs.exists(file) then
		return nil
	end

	local succeeded, record = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)
	local pid = if succeeded and record then record.pid else nil
	local url = if succeeded and record then record.url else nil

	if not record or record.storage == "files" then
		return nil
	end

	if type(pid) ~= "number" or type(url) ~= "string" or not isProcessAlive(pid) then
		return nil
	end

	local responded, response = pcall(function()
		return net.request(`{url}/api/canvases`)
	end)

	return if responded and response.status == 200 then pid else nil
end

local function getLegacyDirs(root: string): { string }
	local dirs: { string } = {}
	local candidates = { root }
	local folder = path.join(root, CANVAS_FOLDER)

	if fs.exists(folder) and fs.type(folder) == "dir" then
		for _, entry in fs.listDirectory(folder) do
			if entry.type == "dir" and isValidWorkspace(entry.name) then
				table.insert(candidates, tostring(path.join(folder, entry.name)))
			end
		end
	end

	for _, dir in candidates do
		if fs.exists(path.join(dir, fileNames.legacyDocument)) then
			table.insert(dirs, dir)
		end
	end

	return dirs
end

local function migrateDir(dir: string)
	runWithLock(dir, function(): nil
		local legacy = tostring(path.join(dir, fileNames.legacyDocument))
		local backup = tostring(path.join(dir, fileNames.legacyBackup))

		-- Another process moved it first.
		if not fs.exists(legacy) then
			return nil
		end

		if not fs.exists(getDocPath(dir)) then
			local contents = fs.readFileToString(legacy)
			local document = json.asObject(json.deserialize(contents) :: json.Value)
			assert(document, `{legacy} must be a JSON object`)
			-- Refuse before moving it, so an older Orion can still upgrade it
			-- in place.
			checkDataVersion(document, legacy)

			if not fs.exists(backup) then
				fs.copy(legacy, backup)
			end

			writeCanvasFiles(dir, document, nil)
		elseif not fs.exists(backup) or fs.readFileToString(backup) ~= fs.readFileToString(legacy) then
			-- A run that stopped after writing the files leaves `orion.json`
			-- matching its backup. Anything else was written after the move,
			-- most likely by an older Orion, and holds changes the files don't.
			error(
				`{legacy} changed after this canvas moved to files, likely written by an older Orion; quit it, `
					.. `then move {legacy} aside and run the command again`
			)
		end

		fs.remove(legacy)
		return nil
	end)
end

--[[
	Moves every canvas in a data folder from one `orion.json` to a folder of
	files: `canvas.json`, `nodes/`, `links/`, and `local.json`. The original
	stays beside them as `orion.backup.json`. Fields are split as they were
	stored, so reading the files later fills in defaults the same way reading
	`orion.json` did. A version 1 `orion.json` stays where it is, so an older
	Orion can still upgrade it. Each canvas moves under its lock, one that
	stopped partway finishes on the next run, and every canvas that can move
	does before the failures are raised. It refuses while an older Orion is
	still serving the folder, since that server would keep writing `orion.json`.
	Returns whether it moved anything.
]]
local function migrateCanvasFiles(root: string, options: Options?): boolean
	local dirs = getLegacyDirs(root)

	if #dirs == 0 then
		return false
	end

	local find = if options and options.findLegacyServer then options.findLegacyServer else findLegacyServer
	local pid = find(root)
	assert(
		pid == nil,
		`an older Orion is serving {root} (pid {pid}); quit it so Orion can move its canvases to folders of files`
	)

	-- One canvas that can't move doesn't hold back the rest.
	local failures: { string } = {}

	for _, dir in dirs do
		local succeeded, failure = pcall(migrateDir, dir)

		if not succeeded then
			table.insert(failures, tostring(failure))
		end
	end

	assert(#failures == 0, table.concat(failures, "\n"))

	return true
end

return migrateCanvasFiles
