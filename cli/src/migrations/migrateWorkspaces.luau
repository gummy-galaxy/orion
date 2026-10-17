local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")

local fileNames = require("@root/fileNames")
local isProcessAlive = require("@root/server/isProcessAlive")

-- Canvases were called workspaces before 0.1.0, and their list and folders were named for it.
local LEGACY_LIST = "workspaces.json"
local LEGACY_FOLDER = "workspaces"
local LEGACY_BACKUP = "workspaces.backup.json"
local CANVAS_FOLDER = "canvases"

export type Options = {
	-- Returns the pid of an older `orion server start` still serving the data folder.
	findLegacyServer: ((root: string) -> number?)?,
}

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

	if type(pid) ~= "number" or type(url) ~= "string" or not isProcessAlive(pid) then
		return nil
	end

	-- Only an older server answers on the old route; anything else holding the pid is a stale record.
	local responded, response = pcall(function()
		return net.request(`{url}/api/workspaces`)
	end)

	return if responded and response.status == 200 then pid else nil
end

-- Another process migrating at the same time may get there first, which counts as done.
local function moveOnce(from: string, to: string)
	local succeeded, failure = pcall(fs.move, from, to)

	if not succeeded and fs.exists(from) then
		error(failure, 0)
	end
end

local function writeCanvasList(root: string, legacyList: string)
	local file = tostring(path.join(root, fileNames.canvases))

	if fs.exists(file) then
		return
	end

	local succeeded, contents = pcall(fs.readFileToString, legacyList)

	-- The list moved to its backup between the check and the read, so another process wrote it.
	if not succeeded then
		assert(fs.exists(file), contents)
		return
	end

	local raw = json.asObject(json.deserialize(contents) :: json.Value)
	assert(raw, `invalid canvas list at {legacyList}`)
	raw.canvases = raw.workspaces
	raw.workspaces = nil

	local temporary = `{file}.tmp.{process.pid()}`
	fs.writeStringToFile(temporary, json.serialize(raw, true))
	moveOnce(temporary, file)
	pcall(fs.remove, temporary)
end

local function moveFolders(root: string, legacyFolder: string)
	local canvasFolder = tostring(path.join(root, CANVAS_FOLDER))

	-- Another process may create it first.
	pcall(function()
		fs.createDirectory(canvasFolder)
	end)
	assert(fs.exists(canvasFolder), `couldn't create {canvasFolder}`)

	for _, entry in fs.listDirectory(legacyFolder) do
		local from = tostring(path.join(legacyFolder, entry.name))
		local to = tostring(path.join(canvasFolder, entry.name))

		if not fs.exists(to) then
			moveOnce(from, to)
		elseif entry.type == "dir" and fs.exists(from) then
			error(`{from} and {to} both exist; move one aside and run the command again`)
		end
	end

	-- Stray files such as .DS_Store keep the folder, and later runs look past them.
	pcall(function()
		fs.removeDirectory(legacyFolder)
	end)
end

--[[
	Moves a data folder from the workspace layout to the canvas one: `workspaces.json` becomes `canvases.json`,
	and `workspaces/<name>/` becomes `canvases/<name>/`. Folders move whole, so each keeps its data and backups,
	and the old list stays beside the new one as `workspaces.backup.json`. Each step checks what's left, so a run
	that stopped partway, or one racing another process, finishes the move. It refuses while an older Orion is
	still serving the folder, since that server would keep writing to the old paths. Returns whether it moved
	anything.
]]
local function migrateWorkspaces(root: string, options: Options?): boolean
	local legacyList = tostring(path.join(root, LEGACY_LIST))
	local legacyFolder = tostring(path.join(root, LEGACY_FOLDER))
	local hasList = fs.exists(legacyList)
	local hasFolder = fs.exists(legacyFolder) and fs.type(legacyFolder) == "dir"

	if not hasList and not hasFolder then
		return false
	end

	local find = if options and options.findLegacyServer then options.findLegacyServer else findLegacyServer
	local pid = find(root)
	assert(
		pid == nil,
		`an older Orion is serving {root} (pid {pid}); quit it so Orion can move this data folder to canvases`
	)

	if hasList then
		writeCanvasList(root, legacyList)
	end

	if hasFolder then
		moveFolders(root, legacyFolder)
	end

	if hasList then
		moveOnce(legacyList, tostring(path.join(root, LEGACY_BACKUP)))
	end

	return true
end

return migrateWorkspaces
