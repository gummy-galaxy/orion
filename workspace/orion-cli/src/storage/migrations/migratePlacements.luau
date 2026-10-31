local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local findOtherServer = require("@root/storage/runtime/findOtherServer")
local getCanvasNames = require("@root/storage/migrations/getCanvasNames")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local runTransaction = require("@root/storage/transactions/runTransaction")

type Server = findOtherServer.Server

export type Options = {
	-- Returns the `orion server start` from another build still serving the
	-- data folder.
	findOtherServer: ((root: string) -> Server?)?,
}

-- Data version 3 is the first to keep positions and groups in placements.
local PLACEMENTS_VERSION = 3

-- Whether a canvas folder's `canvas.json` is from before placements. One that
-- doesn't parse is left for the next read to report.
local function needsPlacements(dir: string): boolean
	local file = tostring(path.join(dir, fileNames.document))

	if not fs.exists(file) then
		return false
	end

	local succeeded, document = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)
	local version = if succeeded and document then document.version else nil

	return type(version) == "number" and version < PLACEMENTS_VERSION
end

--[[
	Moves each node's position and group out of its file and into its first
	placement, in `placements/`, for every canvas in a data folder saved before
	placements. Any write does the move, since nodes are read with the position
	they stored and written without it, so each canvas gets one write, backed up
	first like any other. It refuses while another build of Orion is serving the
	folder, since that server would keep writing positions onto nodes. Returns
	whether it moved anything.
]]
local function migratePlacements(root: string, options: Options?): boolean
	local dirs: { { canvas: string, dir: string } } = {}

	for _, canvas in getCanvasNames(root) do
		local dir = getWorkspaceDir(root, canvas)

		if needsPlacements(dir) then
			table.insert(dirs, { canvas = canvas, dir = dir })
		end
	end

	if #dirs == 0 then
		return false
	end

	local find = if options and options.findOtherServer then options.findOtherServer else findOtherServer
	local server = find(root)

	if server then
		local build = if server.version then ` {server.version}` else ""
		error(
			`another Orion{build} is serving {root} (pid {server.pid}); quit it so Orion can move card positions into placements`,
			0
		)
	end

	-- One canvas that can't move doesn't hold back the rest.
	local failures: { string } = {}

	for _, entry in dirs do
		local succeeded, failure = pcall(runTransaction, entry.dir, function() end)

		if not succeeded then
			table.insert(failures, `{entry.canvas}: {failure}`)
		end
	end

	assert(#failures == 0, table.concat(failures, "\n"))

	return true
end

return migratePlacements
