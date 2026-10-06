local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local path = require("@std/path")

local store = require("@root/store")

type Request = net.ReceivedRequest
type Response = { status: number, body: string, headers: { [string]: string } }
type SyncLoop = { getStatus: () -> json.Object, run: (boolean?) -> json.Object }

local routes = {}

local function reply(status: number, value: json.Value): Response
	return { status = status, body = json.serialize(value), headers = { ["content-type"] = "application/json" } }
end

local function parseBody(request: Request): json.Object
	return assert(json.asObject(json.deserialize(request.body) :: json.Value), "body must be an object")
end

local function getStringField(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

local function getContentType(file: string): string
	local extension = file:match("%.([^.]+)$")
	if extension == "html" then
		return "text/html; charset=utf-8"
	end
	if extension == "js" then
		return "text/javascript; charset=utf-8"
	end
	if extension == "css" then
		return "text/css; charset=utf-8"
	end
	if extension == "json" then
		return "application/json"
	end
	if extension == "svg" then
		return "image/svg+xml"
	end
	if extension == "png" then
		return "image/png"
	end
	if extension == "ico" then
		return "image/x-icon"
	end
	if extension == "woff2" then
		return "font/woff2"
	end
	return "application/octet-stream"
end

local function isKnownWorkspace(root: string, name: string): boolean
	if not store.isValidWorkspace(name) then
		return false
	end
	for _, entry in store.getWorkspaces(root).workspaces do
		if entry.name == name then
			return true
		end
	end
	return false
end

function routes.serveStatic(folder: string, requestPath: string): Response
	local name = requestPath:gsub("^/", "")
	if name == "" then
		name = "index.html"
	end
	if name:find("..", 1, true) or name:find("\\", 1, true) then
		return reply(404, json.object({ error = "not found" }))
	end
	local file = tostring(path.join(folder, name))
	if not fs.exists(file) or fs.type(file) ~= "file" then
		file = tostring(path.join(folder, "index.html"))
	end
	if not fs.exists(file) then
		return reply(404, json.object({ error = "not found" }))
	end
	return { status = 200, body = fs.readFileToString(file), headers = { ["content-type"] = getContentType(file) } }
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
		active = name
		onSwitch(name)
	end

	function router.handle(request: Request): Response
		local route = request.path
		local method = request.method
		if route == "/api/orion" then
			local didSucceed, response = pcall(function(): Response
				local dir = store.getWorkspaceDir(root, active)
				if method == "GET" then
					local requested = request.headers["x-orion-workspace"] or active
					if not isKnownWorkspace(root, requested) then
						return reply(404, json.object({ error = `unknown workspace: {requested}` }))
					end
					local requestedDir = store.getWorkspaceDir(root, requested)
					local doc = store.read(requestedDir)
					if not doc then
						return reply(404, json.object({ path = store.filePath(requestedDir), workspace = requested }))
					end
					return reply(200, assert(doc.raw))
				elseif method == "PUT" then
					local tagged = request.headers["x-orion-workspace"]
					if tagged and tagged ~= active then
						return reply(409, json.object({ error = "workspace changed" }))
					end
					local change = parseBody(request)
					local base = change.baseRevision
					assert(base == json.null or type(base) == "number", "baseRevision must be a number or null")
					local nodes = assert(json.asArray(change.nodes), "nodes must be an array")
					local links = assert(json.asArray(change.links), "links must be an array")
					local isSaved, revision =
						store.put(dir, if base == json.null then nil else base :: number, nodes, links)
					return reply(if isSaved then 200 else 409, json.object({ revision = revision or json.null }))
				end
				return reply(405, json.object({ error = "method not allowed" }))
			end)
			return if didSucceed then response :: Response else reply(500, json.object({ error = tostring(response) }))
		end
		if route == "/api/workspaces" or route == "/api/workspaces/active" then
			local didSucceed, response = pcall(function(): Response
				if route == "/api/workspaces" and method == "GET" then
					local list = store.getWorkspaces(root)
					return reply(200, json.object({ active = active, workspaces = list.workspaces }))
				elseif route == "/api/workspaces" and method == "POST" then
					local change = parseBody(request)
					local name = getStringField(change.name)
					assert(name, `invalid workspace name: {tostring(change.name)}`)
					local label = getStringField(change.label)
					assert(change.label == nil or label, "label must be nonempty")
					local list = store.createWorkspace(root, name, label)
					return reply(201, json.object({ active = active, workspaces = list.workspaces }))
				elseif route == "/api/workspaces/active" and method == "POST" then
					local name = getStringField(parseBody(request).name)
					assert(name, "invalid workspace name")
					local list = store.useWorkspace(root, name)
					router.switchTo(name)
					return reply(200, json.object({ active = active, workspaces = list.workspaces }))
				end
				return reply(404, json.object({ error = "not found" }))
			end)
			return if didSucceed then response :: Response else reply(400, json.object({ error = tostring(response) }))
		end
		if route == "/api/sync" then
			if method == "GET" then
				return reply(200, syncLoop.getStatus())
			end
			if method == "POST" then
				return reply(200, syncLoop.run(request.query.force == "1"))
			end
			return reply(405, json.object({ error = "method not allowed" }))
		end
		if route:sub(1, 5) == "/api/" or route == "/api" then
			return reply(404, json.object({ error = "not found" }))
		end
		if staticDir and method == "GET" then
			return routes.serveStatic(staticDir, route)
		end
		return reply(404, json.object({ error = "not found" }))
	end

	return router
end

return table.freeze(routes)
