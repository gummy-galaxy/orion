local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local encodeStableJson = require("@root/store/encodeStableJson")
local fileNames = require("@root/fileNames")
local findOtherServer = require("@root/server/findOtherServer")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local isValidWorkspace = require("@root/store/isValidWorkspace")
local replaceFile = require("@root/store/replaceFile")
local runTransaction = require("@root/store/runTransaction")
local runWithLock = require("@root/store/runWithLock")

type Server = findOtherServer.Server

local CANVAS_FOLDER = "canvases"

export type Options = {
	-- Returns the `orion server start` from another build still serving the
	-- data folder.
	findOtherServer: ((root: string) -> Server?)?,
}

type Found = { canvas: string, dir: string, commands: json.Object }

local function getCanvasNames(root: string): { string }
	local names = { "default" }
	local folder = path.join(root, CANVAS_FOLDER)

	if fs.exists(folder) and fs.type(folder) == "dir" then
		for _, entry in fs.listDirectory(folder) do
			if entry.type == "dir" and entry.name ~= "default" and isValidWorkspace(entry.name) then
				table.insert(names, entry.name)
			end
		end
	end

	return names
end

-- The commands a canvas's `canvas.json` keeps on its sources, by source id, or
-- nil when it keeps none.
local function readCommands(dir: string): json.Object?
	local file = tostring(path.join(dir, fileNames.document))

	if not fs.exists(file) then
		return nil
	end

	local succeeded, document = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)
	local settings = if succeeded and document then json.asObject(document.settings) else nil
	local commands = json.object({})
	local found = false

	for _, raw in (if settings then json.asArray(settings.sources) else nil) or {} do
		local source = json.asObject(raw)
		local command = if source then json.asArray(source.command) else nil

		if source and type(source.id) == "string" and command and #command > 0 then
			commands[source.id] = command
			found = true
		end
	end

	return if found then commands else nil
end

--[[
	Moves the commands sources kept in each canvas's `canvas.json` into the data
	folder's `commands.json`, keyed by canvas name, then rewrites each
	`canvas.json` without them. It runs once: the first run writes
	`commands.json`, even with nothing to move, and later runs leave alone a
	command a cloned canvas brings in its `canvas.json`, which Orion no longer
	reads. It refuses while another build of Orion is serving the folder, since
	that server would keep running the commands it read. Returns whether it
	moved anything.
]]
local function migrateSourceCommands(root: string, options: Options?): boolean
	local file = path.join(root, fileNames.commands)

	if fs.exists(file) then
		return false
	end

	local found: { Found } = {}
	local all = json.object({})

	for _, canvas in getCanvasNames(root) do
		local dir = getWorkspaceDir(root, canvas)
		local commands = readCommands(dir)

		if commands then
			table.insert(found, { canvas = canvas, dir = dir, commands = commands })
			all[canvas] = commands
		end
	end

	if #found > 0 then
		local find = if options and options.findOtherServer then options.findOtherServer else findOtherServer
		local server = find(root)

		if server then
			local build = if server.version then ` {server.version}` else ""
			error(
				`another Orion{build} is serving {root} (pid {server.pid}); `
					.. `quit it so Orion can move source commands out of canvas files`,
				0
			)
		end
	end

	-- Written before the canvases change, so a run that stops partway keeps
	-- every command.
	runWithLock(root, function(): nil
		if not fs.exists(file) then
			replaceFile(root, fileNames.commands, encodeStableJson(all))
		end

		return nil
	end)

	-- Orion no longer writes a source's command into `canvas.json`, so any
	-- write drops it.
	local failures: { string } = {}

	for _, entry in found do
		local succeeded, failure = pcall(runTransaction, entry.dir, function() end)

		if not succeeded then
			table.insert(failures, `{entry.canvas}: {failure}`)
		end
	end

	assert(#failures == 0, table.concat(failures, "\n"))

	return #found > 0
end

return migrateSourceCommands
