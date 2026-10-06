local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local path = require("@std/path")
local test = require("@std/test")

local routes = require("@root/server/routes")
local store = require("@root/store")
local testing = require("@root/testing")

local function createRequest(
	method: string,
	route: string,
	value: json.Object?,
	workspace: string?
): net.ReceivedRequest
	local headers: { [string]: string } = {}
	if workspace then
		headers["x-orion-workspace"] = workspace
	end
	return {
		method = method,
		path = route,
		body = if value then json.serialize(value) else "",
		query = {} :: { [string]: string },
		headers = headers,
	}
end

local function decodeResponse(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

local function createRouter(name: string)
	local root = testing.directory(name)
	local status = json.object({ state = "idle" })
	local router
	router = routes.create(root, "default", {
		getStatus = function()
			return status
		end,
		run = function()
			return status
		end,
	}, function() end)
	return root, router
end

test.case("GET reports a missing file and PUT creates it with a guarded revision", function(assert)
	local root, router = createRouter("routes-missing")
	local missing = router.handle(createRequest("GET", "/api/orion"))
	assert.eq(missing.status, 404)
	assert.eq(decodeResponse(missing).path, store.filePath(root))
	assert.eq(decodeResponse(missing).workspace, "default")
	local change = json.object({ baseRevision = json.null, nodes = {}, links = {} })
	local saved = router.handle(createRequest("PUT", "/api/orion", change))
	assert.eq(saved.status, 200)
	assert.eq(decodeResponse(saved).revision, 0)
	assert.eq(router.handle(createRequest("PUT", "/api/orion", change)).status, 409)
	assert.eq(decodeResponse(router.handle(createRequest("PUT", "/api/orion", change))).revision, 0)
end)

test.case("PUT retains unknown top-level fields and rejects a stale workspace", function(assert)
	local root, router = createRouter("routes-preserve")
	local doc = testing.createDoc({}, {})
	doc.raw = json.object({ extra = json.object({ held = true }) })
	store.write(root, doc)
	local change = json.object({ baseRevision = 0, nodes = {}, links = {} })
	assert.eq(router.handle(createRequest("PUT", "/api/orion", change, "other")).status, 409)
	assert.eq(router.handle(createRequest("PUT", "/api/orion", change, "default")).status, 200)
	local updated = decodeResponse(router.handle(createRequest("GET", "/api/orion")))
	assert.eq(updated.revision, 1)
	local extra = json.asObject(updated.extra)
	assert.eq(if extra then extra.held else nil, true)
	assert.eq(#store.getBackups(root), 1)
end)

test.case("workspace routes create, list, and switch", function(assert)
	local root, router = createRouter("routes-workspaces")
	local created =
		router.handle(createRequest("POST", "/api/workspaces", json.object({ name = "planning", label = "Planning" })))
	assert.eq(created.status, 201)
	assert.eq(decodeResponse(created).active, "default")
	local createdDoc = store.read(store.getWorkspaceDir(root, "planning"))
	assert.eq(if createdDoc then createdDoc.revision else nil, 0)
	local switched = router.handle(createRequest("POST", "/api/workspaces/active", json.object({ name = "planning" })))
	assert.eq(switched.status, 200)
	assert.eq(decodeResponse(switched).active, "planning")
	assert.eq(decodeResponse(router.handle(createRequest("GET", "/api/workspaces"))).active, "planning")
	assert.eq(
		router.handle(
			createRequest("PUT", "/api/orion", json.object({ baseRevision = 0, nodes = {}, links = {} }), "default")
		).status,
		409
	)
end)

test.case("GET reads the workspace a request names", function(assert)
	local root, router = createRouter("routes-requested")
	store.createWorkspace(root, "planning", "Planning")
	local planning = router.handle(createRequest("GET", "/api/orion", nil, "planning"))
	assert.eq(planning.status, 200)
	assert.eq(decodeResponse(planning).revision, 0)
	local missing = router.handle(createRequest("GET", "/api/orion", nil, "default"))
	assert.eq(missing.status, 404)
	assert.eq(decodeResponse(missing).workspace, "default")
	assert.eq(router.handle(createRequest("GET", "/api/orion", nil, "unknown")).status, 404)
	assert.eq(router.getActive(), "default")
end)

test.case("static route serves files and falls back to index outside the API", function(assert)
	local root, _router = createRouter("routes-static")
	local folder = tostring(path.join(root, "site"))
	fs.createDirectory(folder, { makeParents = true })
	fs.writeStringToFile(path.join(folder, "index.html"), "home")
	fs.writeStringToFile(path.join(folder, "app.js"), "code")
	local router = routes.create(root, "default", {
		getStatus = function()
			return json.object({ state = "idle" })
		end,
		run = function()
			return json.object({ state = "idle" })
		end,
	}, function() end, folder)
	assert.eq(router.handle(createRequest("GET", "/app.js")).body, "code")
	assert.eq(router.handle(createRequest("GET", "/deep/link")).body, "home")
	assert.eq(router.handle(createRequest("GET", "/api/unknown")).status, 404)
end)
