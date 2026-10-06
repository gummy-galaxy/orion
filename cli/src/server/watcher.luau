local fs = require("@std/fs")
local task = require("@std/task")

local store = require("@root/store")

local watcher = {}

function watcher.new(root: string, active: () -> string, switchTo: (string) -> (), changed: (number) -> ())
	local isClosed = false
	local watchedWorkspace = active()
	local lastManifestActive = store.workspaces(root).active
	local folder = fs.watch(store.workspaceDir(root, watchedWorkspace))
	local manifest = fs.watch(root)
	local generation = 0
	local function revision(name: string): number?
		local didSucceed, doc = pcall(store.read, store.workspaceDir(root, name))
		return if didSucceed and doc then doc.revision else nil
	end
	local lastRevision = revision(watchedWorkspace)
	local monitor = {}

	function monitor.switchTo(name: string)
		folder:close()
		watchedWorkspace = name
		local dir = store.workspaceDir(root, name)
		if not fs.exists(dir) then
			fs.createDirectory(dir, { makeParents = true })
		end
		folder = fs.watch(dir)
		lastRevision = revision(name)
		generation += 1
	end

	local function scheduleChange()
		generation += 1
		local scheduled = generation
		task.delay(0.06, function()
			if isClosed or scheduled ~= generation then
				return
			end
			local didSucceed, doc = pcall(store.read, store.workspaceDir(root, active()))
			if didSucceed and doc and doc.revision ~= lastRevision then
				lastRevision = doc.revision
				changed(doc.revision)
			end
		end)
	end

	local function checkChange()
		local current = revision(active())
		if current ~= nil and current ~= lastRevision then
			scheduleChange()
		end
	end

	function monitor.start()
		task.spawn(function()
			while not isClosed do
				while manifest:next() do
				end
				local didSucceed, list = pcall(store.workspaces, root)
				if didSucceed and list and list.active ~= lastManifestActive then
					lastManifestActive = list.active
					if list.active ~= active() then
						switchTo(list.active)
					end
				end
				local hasFolderEvent = false
				while folder:next() do
					hasFolderEvent = true
				end
				if hasFolderEvent then
					scheduleChange()
				end
				checkChange()
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
