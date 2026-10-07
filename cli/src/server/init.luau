local filesystem = require("@std/fs")
local json = require("@std/json")
local network = require("@lute/net/server")
local task = require("@std/task")

local events = require("@root/server/events")
local routes = require("@root/server/routes")
local store = require("@root/store")
local sync = require("@root/server/sync")
local watcher = require("@root/server/watcher")

local server = {}

function server.start(root: string, workspace: string, host: string, port: number, staticDirectory: string?)
	if not filesystem.exists(root) then
		filesystem.createDirectory(root, { makeParents = true })
	end

	local directory = store.getWorkspaceDirectory(root, workspace)

	if not filesystem.exists(directory) then
		filesystem.createDirectory(directory, { makeParents = true })
	end
	local function clearFocus()
		for _, entry in store.getWorkspaces(root).workspaces do
			store.clearFocus(store.getWorkspaceDirectory(root, entry.name))
		end
	end
	clearFocus()
	local hub = events.create()
	local syncLoop = sync.create(root, workspace, function(status: json.Object)
		hub.publish("orion:sync", status)
	end)

	local monitor
	local router = routes.create(root, workspace, syncLoop, function(name: string)
		assert(monitor).switchTo(name)
		syncLoop.switchTo(name)
		hub.publish("orion:workspace", json.object({ active = name }))
		task.spawn(function()
			syncLoop.run(true)
		end)
	end, staticDirectory)
	monitor = watcher.create(root, router.getActive, router.switchTo, function(revision: number)
		hub.publish("orion:changed", json.object({ revision = revision }))
	end)

	local running = network.serve({
		hostname = host,
		port = port,
		handler = function(request, socketServer)
			if request.path == "/api/events" then
				if socketServer:upgrade(request) then
					return nil
				end

				return { status = 400, body = "WebSocket upgrade required" }
			end

			return router.handle(request) :: network.ServerResponse
		end,

		websocket = {
			open = hub.open,
			close = function(socket)
				hub.close(socket)
			end,
		},
	})
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
			clearFocus()
		end,
	}
end

return table.freeze(server)
