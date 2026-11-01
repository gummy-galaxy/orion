local json = require("@std/json")
local net = require("@lute/net/server")
local process = require("@std/process")
local task = require("@std/task")

local clearFocus = require("@root/storage/focus/clearFocus")
local createTelemetrySender = require("@root/server/createTelemetrySender")
local deriveTimed = require("@root/server/deriveTimed")
local ensureDirectory = require("@root/common/platform/ensureDirectory")
local events = require("@root/server/events")
local getVersion = require("@root/common/getVersion")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local isTrustedRequest = require("@root/server/isTrustedRequest")
local performanceSummaries = require("@root/server/performanceSummaries")
local queries = require("@root/server/queries")
local readRuntime = require("@root/storage/runtime/readRuntime")
local removeRuntime = require("@root/storage/runtime/removeRuntime")
local routes = require("@root/server/routes")
local serializeDerived = require("@root/server/serializeDerived")
local sessions = require("@root/server/sessions")
local storeTypes = require("@root/storage/types")
local sync = require("@root/server/sync")
local types = require("@root/types")
local watcher = require("@root/server/watcher")
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
	local hub = events.create()
	local syncLoop = sync.create(root, workspace, function(status: json.Object)
		hub.publish("orion:sync", status)
	end)

	local monitor
	local openQueries = queries.create(root)
	local summaries = performanceSummaries.create(root, { environment = process.env })
	local router = routes.create(root, workspace, syncLoop, function(name: string)
		assert(monitor).switchTo(name)
		syncLoop.switchTo(name)
		if runtime then
			runtime.canvas = name
			writeRuntime(root, runtime)
		end
		hub.publish("orion:canvas", json.object({ active = name }))
		openQueries.refresh(name)
		task.spawn(function()
			syncLoop.runAsync(true)
		end)
	end, staticDir, hub, summaries)
	monitor = watcher.create(
		root,
		router.getActive,
		router.switchTo,
		function(revision: number, doc: types.Doc, isReindexed)
			local event = json.object({ revision = revision, derived = serializeDerived(deriveTimed(doc, summaries)) })

			-- Files changed outside Orion without a new revision, so the app
			-- reloads despite seeing its own revision.
			if isReindexed then
				event.reindexed = true
			end

			hub.publish("orion:changed", event)
			openQueries.refresh(router.getActive())
		end,
		function(list: WorkspaceList)
			hub.publish("orion:canvases", json.object({ active = list.active, canvases = list.workspaces }))
		end,
		function(name: string)
			hub.publish("orion:log", json.object({ canvas = name }))
		end
	)

	local sessionLoop = sessions.create(root, router.getActive)
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
			open = hub.open,
			message = function(socket, message)
				openQueries.receive(socket, message, router.getActive())
			end,
			close = function(socket)
				hub.close(socket)
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
	monitor.start()
	sessionLoop.start()
	telemetrySender.start()
	summaries.start()
	task.delay(5, function()
		while true do
			syncLoop.tickAsync()
			task.wait(sync.TICK_SECONDS)
		end
	end)

	return {
		hostname = running.hostname,
		port = running.port,
		close = function()
			assert(monitor).close()
			sessionLoop.close()
			telemetrySender.close()
			summaries.close()
			running.close()
			removeRuntime(root, runtime)
			clearAllFocus()
		end,
	}
end

return table.freeze(server)
