local json = require("@std/json")
local net = require("@lute/net/server")
local process = require("@std/process")
local task = require("@std/task")

local clearFocus = require("@root/store/clearFocus")
local ensureDirectory = require("@root/platform/ensureDirectory")
local events = require("@root/server/events")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local graph = require("@root/graph")
local readRuntime = require("@root/server/readRuntime")
local removeRuntime = require("@root/server/removeRuntime")
local routes = require("@root/server/routes")
local serializeDerived = require("@root/server/serializeDerived")
local storeTypes = require("@root/store/types")
local sync = require("@root/server/sync")
local types = require("@root/types")
local watcher = require("@root/server/watcher")
local writeRuntime = require("@root/server/writeRuntime")

type Runtime = readRuntime.Runtime
type WorkspaceList = storeTypes.WorkspaceList

local server = {}

function server.start(root: string, workspace: string, host: string, port: number, staticDir: string?)
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
	local router = routes.create(root, workspace, syncLoop, function(name: string)
		assert(monitor).switchTo(name)
		syncLoop.switchTo(name)
		if runtime then
			runtime.canvas = name
			writeRuntime(root, runtime)
		end
		hub.publish("orion:canvas", json.object({ active = name }))
		task.spawn(function()
			syncLoop.run(true)
		end)
	end, staticDir)
	monitor = watcher.create(root, router.getActive, router.switchTo, function(revision: number, doc: types.Doc)
		hub.publish(
			"orion:changed",
			json.object({ revision = revision, derived = serializeDerived(graph.derive(doc)) })
		)
	end, function(list: WorkspaceList)
		hub.publish("orion:canvases", json.object({ active = list.active, canvases = list.workspaces }))
	end, function(name: string)
		hub.publish("orion:log", json.object({ canvas = name }))
	end)

	local running = net.serve({
		hostname = host,
		port = port,
		handler = function(request, socketServer)
			if request.path == "/api/events" then
				if socketServer:upgrade(request) then
					return nil
				end

				return { status = 400, body = "WebSocket upgrade required" }
			end

			return router.handle(request) :: net.ServerResponse
		end,

		websocket = {
			open = hub.open,
			close = function(socket)
				hub.close(socket)
			end,
		},
	})
	runtime = {
		pid = process.pid(),
		url = `http://{running.hostname}:{running.port}`,
		canvas = workspace,
		dataFolder = root,
		startedAt = startedAt,
	}
	writeRuntime(root, runtime)
	monitor.start()
	task.delay(5, function()
		syncLoop.run()
	end)

	task.spawn(function()
		while true do
			task.wait(5 * 60)
			syncLoop.run()
		end
	end)

	return {
		hostname = running.hostname,
		port = running.port,
		close = function()
			assert(monitor).close()
			running.close()
			removeRuntime(root, runtime)
			clearAllFocus()
		end,
	}
end

return table.freeze(server)
