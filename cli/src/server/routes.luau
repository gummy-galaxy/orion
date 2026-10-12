local json = require("@std/json")
local net = require("@lute/net/server")

local canvasStyle = require("@root/server/routes/canvasStyle")
local editor = require("@root/server/routes/editor")
local focus = require("@root/server/routes/focus")
local imageRoutes = require("@root/server/routes/images")
local links = require("@root/server/routes/links")
local merge = require("@root/server/routes/merge")
local orion = require("@root/server/routes/orion")
local settings = require("@root/server/routes/settings")
local shared = require("@root/server/routes/shared")
local static = require("@root/server/routes/static")
local store = require("@root/store")
local sync = require("@root/server/routes/sync")
local themes = require("@root/server/routes/themes")
local workspaces = require("@root/server/routes/workspaces")

type Request = net.ReceivedRequest
type Response = shared.Response
type SyncLoop = sync.SyncLoop

local routes = {}

function routes.serveStatic(folder: string, requestPath: string): Response
	return static.serve(folder, requestPath)
end

function routes.create(
	root: string,
	initialWorkspace: string,
	syncLoop: SyncLoop,
	onSwitch: (string) -> (),
	staticDir: string?
)
	local active = initialWorkspace
	local router = {}

	function router.getActive(): string
		return active
	end

	function router.switchTo(name: string)
		if name == active then
			return
		end
		store.clearFocus(store.getWorkspaceDir(root, active))
		store.clearFocus(store.getWorkspaceDir(root, name))
		active = name
		onSwitch(name)
	end

	function router.handle(request: Request): Response
		local route = request.path
		if imageRoutes.matches(route) then
			return imageRoutes.handle(request, root)
		end
		if route == "/api/orion" then
			return orion.handle(request, root, active)
		end
		if route == "/api/orion/style" then
			return canvasStyle.handle(request, root, active)
		end
		if route == "/api/focus" then
			return focus.handle(request, root, active)
		end
		if route == "/api/editor" then
			return editor.handle(request)
		end
		if route == "/api/merge" then
			return merge.handle(request, syncLoop)
		end
		if route == "/api/links" then
			return links.handle(request, root)
		end
		if route == "/api/settings" then
			return settings.handle(request, root)
		end
		if route == "/api/themes" then
			return themes.handle(request, root)
		end

		if route == "/api/workspaces" or route == "/api/workspaces/active" then
			return workspaces.handle(request, root, router.getActive, router.switchTo)
		end

		if route == "/api/sync" then
			return sync.handle(request, syncLoop)
		end

		if route:sub(1, 5) == "/api/" or route == "/api" then
			return shared.reply(404, json.object({ error = "not found" }))
		end
		if staticDir and request.method == "GET" then
			return routes.serveStatic(staticDir, route)
		end
		return shared.reply(404, json.object({ error = "not found" }))
	end

	return router
end

return table.freeze(routes)
