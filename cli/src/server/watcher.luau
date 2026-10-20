local fs = require("@std/fs")
local path = require("@std/path")
local task = require("@std/task")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local getLogPath = require("@root/log/getLogPath")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local readDoc = require("@root/store/readDoc")
local storeTypes = require("@root/store/types")
local types = require("@root/types")

type Doc = types.Doc
type WorkspaceList = storeTypes.WorkspaceList
type Stamp = { size: number, modified: number }

local watcher = {}

-- Every write replaces the canvas's local.json last, so its stamp moves once per write.
local function getWrittenPath(dir: string): string
	return tostring(path.join(dir, fileNames.localState))
end

local function getStamp(file: string): Stamp?
	local didSucceed, metadata = pcall(fs.metadata, file)

	if not didSucceed or metadata.type ~= "file" then
		return nil
	end

	return { size = metadata.size, modified = metadata.modified:toNanoseconds() }
end

local function hasStampChanged(previous: Stamp?, current: Stamp?): boolean
	if previous == nil or current == nil then
		return previous ~= current
	end

	return previous.size ~= current.size or previous.modified ~= current.modified
end

function watcher.create(
	root: string,
	active: () -> string,
	switchTo: (string) -> (),
	changed: (number, Doc) -> (),
	workspacesChanged: (WorkspaceList) -> (),
	logChanged: (string) -> ()
)
	local isClosed = false
	local dataFile = getWrittenPath(getWorkspaceDir(root, active()))
	local logFile = getLogPath(getWorkspaceDir(root, active()))
	local logName = active()
	local manifestFile = tostring(path.join(root, fileNames.canvases))
	local lastDataStamp = getStamp(dataFile)
	local lastLogStamp = getStamp(logFile)
	local lastManifestStamp = getStamp(manifestFile)
	local lastManifestActive = getWorkspaces(root).active
	local folder = fs.watch(getWorkspaceDir(root, active()))
	local manifest = fs.watch(root)
	local generation = 0
	local monitor = {}

	local function getDoc(): Doc?
		local didSucceed, doc = pcall(readDoc, getWorkspaceDir(root, active()))
		return if didSucceed then doc else nil
	end

	local function getRevision(): number?
		local doc = getDoc()
		return if doc then doc.revision else nil
	end

	local lastRevision = getRevision()

	function monitor.switchTo(name: string)
		folder:close()
		local dir = getWorkspaceDir(root, name)

		ensureDirectory(dir)

		folder = fs.watch(dir)
		dataFile = getWrittenPath(dir)
		logFile = getLogPath(dir)
		logName = name
		lastDataStamp = getStamp(dataFile)
		lastLogStamp = getStamp(logFile)
		lastRevision = getRevision()
		generation += 1
	end

	local function scheduleChange()
		generation += 1
		local scheduled = generation
		task.delay(0.06, function()
			if isClosed or scheduled ~= generation then
				return
			end

			local current = getStamp(dataFile)

			if not hasStampChanged(lastDataStamp, current) then
				return
			end

			if current == nil then
				lastDataStamp = nil
				lastRevision = nil
				return
			end

			local doc = getDoc()

			if doc == nil then
				return -- A writer may still be finishing; retry on the next check.
			end

			lastDataStamp = current

			if doc.revision ~= lastRevision then
				lastRevision = doc.revision
				changed(doc.revision, doc)
			end
		end)
	end

	local function checkChange()
		if hasStampChanged(lastDataStamp, getStamp(dataFile)) then
			scheduleChange()
		end
	end

	-- Log appends don't change the document, so they get their own stamp and announcement.
	local function checkLog()
		local current = getStamp(logFile)

		if hasStampChanged(lastLogStamp, current) then
			lastLogStamp = current
			logChanged(logName)
		end
	end

	local function checkWorkspace()
		local current = getStamp(manifestFile)

		if not hasStampChanged(lastManifestStamp, current) then
			return
		end

		local didSucceed, list = pcall(getWorkspaces, root)

		if not didSucceed or not list then
			return -- Retry if a concurrent writer has not finished the manifest.
		end

		lastManifestStamp = current
		workspacesChanged(list)

		if list.active ~= lastManifestActive then
			lastManifestActive = list.active

			if list.active ~= active() then
				switchTo(list.active)
			end
		end
	end

	function monitor.start()
		task.spawn(function()
			while not isClosed do
				while manifest:next() do
				end

				checkWorkspace()

				while folder:next() do
				end

				checkChange()
				checkLog()
				task.wait(0.1)
			end
		end)
	end

	function monitor.close()
		isClosed = true
		folder:close()
		manifest:close()
	end

	return monitor
end

return table.freeze(watcher)
