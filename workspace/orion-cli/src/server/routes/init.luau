local json = require("@std/json")
local net = require("@lute/net/server")

local canvasStyle = require("@root/server/routes/canvasStyle")
local canvases = require("@root/server/routes/canvases")
local checkSnoozes = require("@root/server/routes/checkSnoozes")
local clearFocus = require("@root/storage/focus/clearFocus")
local editor = require("@root/server/routes/editor")
local focus = require("@root/server/routes/focus")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local imageRoutes = require("@root/server/routes/images")
local links = require("@root/server/routes/links")
local log = require("@root/server/routes/log")
local merge = require("@root/server/routes/merge")
local operations = require("@root/server/routes/operations")
local orion = require("@root/server/routes/orion")
local performanceSummaries = require("@root/server/performanceSummaries")
local query = require("@root/server/routes/query")
local reveal = require("@root/server/routes/reveal")
local sessions = require("@root/server/routes/sessions")
local settings = require("@root/server/routes/settings")
local shared = require("@root/server/routes/shared")
local static = require("@root/server/routes/static")
local sync = require("@root/server/routes/sync")
local telemetry = require("@root/server/routes/telemetry")
local themes = require("@root/server/routes/themes")

type Request = net.ReceivedRequest
type Response = shared.Response
type SyncLoop = sync.SyncLoop
type RevealHub = reveal.Hub

local routes = {}

function routes.serveStatic(folder: string, requestPath: string, host: string?): Response
	return static.serve(folder, requestPath, host)
end

function routes.create(
	root: string,
	initialWorkspace: string,
	syncLoop: SyncLoop,
	onSwitch: (string) -> (),
	staticDir: string?,
	hub: RevealHub?,
	timings: performanceSummaries.Timings?
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
		clearFocus(getWorkspaceDir(root, active))
		clearFocus(getWorkspaceDir(root, name))
		active = name
		onSwitch(name)
	end

	function router.handleAsync(request: Request): Response
		local route = request.path
		if imageRoutes.matches(route) then
			return imageRoutes.handle(request, root)
		end
		if route == "/api/orion" then
			return orion.handle(request, root, active, timings)
		end
		if route == "/api/orion/style" then
			return canvasStyle.handle(request, root, active)
		end
		if route == "/api/orion/check-snoozes" then
			return checkSnoozes.handle(request, root, active)
		end
		if route == "/api/operations" then
			return operations.handle(request, root, active, timings)
		end
		if route == "/api/query" then
			return query.handle(request, root, active)
		end
		if route == "/api/focus" then
			return focus.handle(request, root, active)
		end
		if route == "/api/reveal" then
			return reveal.handle(request, root, router.getActive, router.switchTo, hub)
		end
		if route == "/api/editor" then
			return editor.handleAsync(request)
		end
		if route == "/api/merge" then
			return merge.handleAsync(request, syncLoop)
		end
		if route == "/api/links" then
			return links.handleAsync(request, root)
		end
		if route == "/api/log" then
			return log.handle(request, root)
		end
		if route == "/api/sessions/turns" then
			return sessions.handleAsync(request, root, router.getActive())
		end
		if route == "/api/settings" then
			return settings.handle(request, root)
		end
		if route == "/api/themes" then
			return themes.handle(request, root)
		end
		if route == "/api/telemetry" then
			return telemetry.handle(request, root)
		end
		if route == "/api/telemetry/events" then
			return telemetry.handleEvents(request, root)
		end

		if route == "/api/canvases" or route == "/api/canvases/active" then
			return canvases.handle(request, root, router.getActive, router.switchTo)
		end

		if route == "/api/sync" then
			return sync.handleAsync(request, syncLoop)
		end

		if route:sub(1, 5) == "/api/" or route == "/api" then
			return shared.reply(404, json.object({ error = "not found" }))
		end
		if staticDir and request.method == "GET" then
			return routes.serveStatic(staticDir, route, request.headers.host)
		end
		return shared.reply(404, json.object({ error = "not found" }))
	end

	return router
end

return table.freeze(routes)
