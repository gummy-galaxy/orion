local json = require("@std/json")
local net = require("@lute/net/server")
local process = require("@std/process")
local task = require("@std/task")

local clearFocus = require("@root/storage/focus/clearFocus")
local createEventHub = require("@root/server/createEventHub")
local createOpenQueries = require("@root/server/createOpenQueries")
local createPerformanceSummaries = require("@root/server/createPerformanceSummaries")
local createRouter = require("@root/server/routes/createRouter")
local createSessionLoop = require("@root/server/createSessionLoop")
local createSyncLoop = require("@root/server/createSyncLoop")
local createTelemetrySender = require("@root/server/createTelemetrySender")
local createWatcher = require("@root/server/createWatcher")
local deriveTimed = require("@root/server/deriveTimed")
local ensureDirectory = require("@root/common/platform/ensureDirectory")
local getVersion = require("@root/common/getVersion")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local isTrustedRequest = require("@root/server/isTrustedRequest")
local readRuntime = require("@root/storage/runtime/readRuntime")
local removeRuntime = require("@root/storage/runtime/removeRuntime")
local serializeDerived = require("@root/server/serializeDerived")
local serverConstants = require("@root/server/constants")
local storeTypes = require("@root/storage/types")
local types = require("@root/types")
local writeRuntime = require("@root/storage/runtime/writeRuntime")

type Runtime = readRuntime.Runtime
type WorkspaceList = storeTypes.WorkspaceList

local server = {}

function server.start(root: string, workspace: string, host: string, port: number, staticDir: string?, devPort: number?)
	local startedAt = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
	local runtime: Runtime?
	ensureDirectory(root)

	local dir = getWorkspaceDir(root, workspace)

	ensureDirectory(dir)

	local function clearAllFocus()
		for _, entry in getWorkspaces(root).workspaces do
			clearFocus(getWorkspaceDir(root, entry.name))
		end
	end
	clearAllFocus()
	local eventHub = createEventHub()
	local syncLoop = createSyncLoop(root, workspace, function(status: json.Object)
		eventHub.publish("orion:sync", status)
	end)

	local watcher
	local openQueries = createOpenQueries(root)
	local performanceSummaries = createPerformanceSummaries(root, { environment = process.env })
	local router = createRouter(root, workspace, syncLoop, function(name: string)
		assert(watcher).switchTo(name)
		syncLoop.switchTo(name)
		if runtime then
			runtime.canvas = name
			writeRuntime(root, runtime)
		end
		eventHub.publish("orion:canvas", json.object({ active = name }))
		openQueries.refresh(name)
		task.spawn(function()
			syncLoop.runAsync(true)
		end)
	end, staticDir, eventHub, performanceSummaries)
	watcher = createWatcher(
		root,
		router.getActive,
		router.switchTo,
		function(revision: number, doc: types.Doc, isReindexed)
			local event =
				json.object({ revision = revision, derived = serializeDerived(deriveTimed(doc, performanceSummaries)) })

			-- Files changed outside Orion without a new revision, so the app
			-- reloads despite seeing its own revision.
			if isReindexed then
				event.reindexed = true
			end

			eventHub.publish("orion:changed", event)
			openQueries.refresh(router.getActive())
		end,
		function(list: WorkspaceList)
			eventHub.publish("orion:canvases", json.object({ active = list.active, canvases = list.workspaces }))
		end,
		function(name: string)
			eventHub.publish("orion:log", json.object({ canvas = name }))
		end
	)

	local sessionLoop = createSessionLoop(root, router.getActive)
	local telemetrySender = createTelemetrySender(root, { environment = process.env, isDevServer = devPort ~= nil })

	local trustedPorts: { number } = {}
	if devPort then
		table.insert(trustedPorts, devPort)
	end

	local running = net.serve({
		hostname = host,
		port = port,
		handler = function(request, socketServer)
			if not isTrustedRequest(request, host, trustedPorts) then
				return { status = 403, body = "Orion only answers its own app" }
			end

			if request.path == "/api/events" then
				if socketServer:upgrade(request) then
					return nil
				end

				return { status = 400, body = "WebSocket upgrade required" }
			end

			return router.handleAsync(request) :: net.ServerResponse
		end,

		websocket = {
			open = eventHub.open,
			message = function(socket, message)
				openQueries.receive(socket, message, router.getActive())
			end,
			close = function(socket)
				eventHub.close(socket)
				openQueries.close(socket)
			end,
		},
	})
	table.insert(trustedPorts, running.port)
	runtime = {
		pid = process.pid(),
		url = `http://{running.hostname}:{running.port}`,
		canvas = workspace,
		dataFolder = root,
		startedAt = startedAt,
		version = getVersion() :: string?,
	}
	writeRuntime(root, runtime)
	watcher.start()
	sessionLoop.start()
	telemetrySender.start()
	performanceSummaries.start()
	task.delay(5, function()
		while true do
			syncLoop.tickAsync()
			task.wait(serverConstants.SYNC_TICK_SECONDS)
		end
	end)

	return {
		hostname = running.hostname,
		port = running.port,
		close = function()
			assert(watcher).close()
			sessionLoop.close()
			telemetrySender.close()
			performanceSummaries.close()
			running.close()
			removeRuntime(root, runtime)
			clearAllFocus()
		end,
	}
end

return table.freeze(server)
