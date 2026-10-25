local archivist = require("@archivist")
local fs = require("@std/fs")
local path = require("@std/path")
local task = require("@std/task")

local decodeDocObject = require("@root/store/decodeDocObject")
local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local getLogPath = require("@root/log/getLogPath")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local readCanvasFiles = require("@root/store/readCanvasFiles")
local storeTypes = require("@root/store/types")
local types = require("@root/types")

type Doc = types.Doc
type WorkspaceList = storeTypes.WorkspaceList
type Stamp = { size: number, modified: number }
type Watch = typeof(fs.watch(""))

local logger = archivist.getLogger("orion.watcher")

local watcher = {}

-- Every write replaces the canvas's local.json last, so its stamp moves once per write.
local function getWrittenPath(dir: string): string
	return tostring(path.join(dir, fileNames.localState))
end

-- Watches a canvas's node and link folders, which change on their own when a `git pull` or an editor touches them.
local function watchEntries(dir: string): { Watch }
	local watches: { Watch } = {}

	for _, folder in { fileNames.nodes, fileNames.links } do
		local succeeded, watch = pcall(fs.watch, path.join(dir, folder))

		if succeeded then
			table.insert(watches, watch)
		end
	end

	return watches
end

local function closeAll(watches: { Watch })
	for _, watch in watches do
		watch:close()
	end
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
	changed: (number, Doc, boolean) -> (),
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
	local entries = watchEntries(getWorkspaceDir(root, active()))
	local manifest = fs.watch(root)
	local generation = 0
	local monitor = {}

	-- The canvas and its fingerprint, which changes with any file's text even when the revision doesn't.
	local function read(): (Doc?, string?)
		local dir = getWorkspaceDir(root, active())
		local didSucceed, snapshot = pcall(readCanvasFiles, dir, false)

		if not didSucceed then
			logger.warn("couldn't read", dir, ":", snapshot)
			return nil, nil
		elseif not snapshot then
			return nil, nil
		end

		return decodeDocObject(snapshot.document), snapshot.fingerprint
	end

	local function getRevision(): (number?, string?)
		local doc, fingerprint = read()
		return if doc then doc.revision else nil, fingerprint
	end

	local lastRevision, lastFingerprint = getRevision()

	function monitor.switchTo(name: string)
		folder:close()
		closeAll(entries)
		local dir = getWorkspaceDir(root, name)

		ensureDirectory(dir)

		folder = fs.watch(dir)
		entries = watchEntries(dir)
		dataFile = getWrittenPath(dir)
		logFile = getLogPath(dir)
		logName = name
		lastDataStamp = getStamp(dataFile)
		lastLogStamp = getStamp(logFile)
		lastRevision, lastFingerprint = getRevision()
		generation += 1
	end

	-- With `isForced`, a node or link file changed, so the canvas is read again even when `local.json` didn't move.
	local function scheduleChange(isForced: boolean)
		generation += 1
		local scheduled = generation
		task.delay(0.06, function()
			if isClosed or scheduled ~= generation then
				return
			end

			local current = getStamp(dataFile)

			if not isForced and not hasStampChanged(lastDataStamp, current) then
				return
			end

			if current == nil then
				lastDataStamp = nil
				lastRevision = nil
				lastFingerprint = nil
				return
			end

			local doc, fingerprint = read()

			if doc == nil then
				return -- A writer may still be finishing; retry on the next check.
			end

			lastDataStamp = current

			if doc.revision ~= lastRevision then
				lastRevision, lastFingerprint = doc.revision, fingerprint
				changed(doc.revision, doc, false)
			elseif fingerprint ~= lastFingerprint then
				-- Files changed outside Orion, such as by a `git pull`, without a new revision.
				lastFingerprint = fingerprint
				logger.info("re-indexed", getWorkspaceDir(root, active()), "after files changed outside Orion")
				changed(doc.revision, doc, true)
			end
		end)
	end

	local function checkChange()
		if hasStampChanged(lastDataStamp, getStamp(dataFile)) then
			scheduleChange(false)
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
					-- Drain queued events.
				end

				checkWorkspace()

				while folder:next() do
					-- Drain queued events.
				end

				local hasEntryChanges = false

				for _, watch in entries do
					while watch:next() do
						hasEntryChanges = true
					end
				end

				if hasEntryChanges then
					scheduleChange(true)
				else
					checkChange()
				end
				checkLog()
				task.wait(0.1)
			end
		end)
	end

	function monitor.close()
		isClosed = true
		folder:close()
		closeAll(entries)
		manifest:close()
	end

	return monitor
end

return table.freeze(watcher)
